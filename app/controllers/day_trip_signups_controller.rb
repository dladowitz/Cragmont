class DayTripSignupsController < ApplicationController
  before_action :require_login
  before_action :set_trip

  def create
    signup = @trip.day_trip_signups.active.find_or_initialize_by(user: current_user)
    minor_attributes = normalized_minor_attributes

    if signup.persisted?
      redirect_to trip_path(@trip), alert: "Wow, that was a whipper. You're already signed up for this day trip."
    elsif none_climbing_ability_selected?
      redirect_to trip_path(@trip), alert: "Choose an available climbing ability before tying in."
    elsif signing_up_with_minors? && minor_attributes.empty?
      redirect_to trip_path(@trip), alert: "Add your minor's details before tying in."
    else
      return unless ensure_waiver_ready(minor_attributes: minor_attributes)

      if create_day_trip_signup(signup, minor_attributes)
        redirect_to trip_path(@trip), notice: "On belay! You've successfully signed up for this day trip."
      else
        redirect_to trip_path(@trip), alert: signup.errors.full_messages.to_sentence
      end
    end
  end

  def destroy
    signup = @trip.day_trip_signups.active.find_by(user: current_user)

    if signup.blank?
      redirect_to trip_path(@trip), alert: "You're not signed up for this day trip.", status: :see_other
    else
      signup.primary_signup.destroy!
      redirect_to trip_path(@trip), notice: "You're off the roster. We'll catch you on the next pitch.", status: :see_other
    end
  end

  private

  def set_trip
    @trip = Trip.published_for_public.day_trip.find(params[:trip_id])
  end

  def signup_params
    params.fetch(:day_trip_signup, {}).permit(
      :with_minor,
      :rope_60m,
      :rope_70m,
      :quickdraws_and_sport_anchor,
      :clip_stick,
      :cams_nuts_and_trad_anchor,
      :crash_pad_count,
      :waiver_signature_data,
      :waiver_acknowledged_at,
      climbing_abilities: [],
      day_trip_signup_minors_attributes: %i[first_name last_name age relationship]
    )
  end

  def signing_up_with_minors?
    signup_params[:with_minor] == "1"
  end

  def normalized_minor_attributes
    return [] unless signing_up_with_minors?

    raw_attributes = signup_params[:day_trip_signup_minors_attributes] || {}
    raw_attributes.values.filter_map do |attributes|
      cleaned = attributes.to_h.transform_values { |value| value.is_a?(Array) ? value : value.to_s.strip }
      next if cleaned.values.all?(&:blank?)

      cleaned
    end.first(DayTripSignup::MAX_MINORS_PER_SIGNUP)
  end

  def create_day_trip_signup(signup, minor_attributes)
    participant_count = 1 + minor_attributes.size

    DayTripSignup.transaction do
      @trip.lock!
      unless @trip.available_for_day_trip_party?(lead_count: 0, top_rope_count: participant_count)
        signup.errors.add(:base, "Wow, that was a whipper. Those spots are full.")
        raise ActiveRecord::RecordInvalid.new(signup)
      end

      signup.assign_attributes(day_trip_signup_attributes)
      minor_attributes.each { |attributes| signup.day_trip_signup_minors.build(attributes) }
      signup.save!
      satisfy_waiver!(signup, minor_attributes)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def day_trip_signup_attributes
    {
      climbing_abilities: signup_climbing_abilities,
      rope_60m: roped_climbing? && truthy_param?(:rope_60m),
      rope_70m: roped_climbing? && truthy_param?(:rope_70m),
      quickdraws_and_sport_anchor: @trip.sport_climbing? && truthy_param?(:quickdraws_and_sport_anchor),
      clip_stick: @trip.sport_climbing? && truthy_param?(:clip_stick),
      cams_nuts_and_trad_anchor: @trip.trad_climbing? && truthy_param?(:cams_nuts_and_trad_anchor),
      crash_pad_count: @trip.bouldering? ? signup_params[:crash_pad_count].to_i.clamp(0, 99) : 0,
      status: "confirmed"
    }
  end

  def signup_climbing_abilities
    @signup_climbing_abilities ||= normalized_climbing_abilities(signup_params[:climbing_abilities])
  end

  def none_climbing_ability_selected?
    signup_climbing_abilities == [ "none" ]
  end

  def normalized_climbing_abilities(values)
    abilities = Array(values).flatten.map(&:to_s).map(&:strip).select do |value|
      allowed_climbing_abilities.include?(value)
    end.uniq
    abilities -= [ "none" ] if abilities.include?("none") && abilities.size > 1
    abilities.presence || [ default_climbing_ability ]
  end

  def allowed_climbing_abilities
    @allowed_climbing_abilities ||= begin
      abilities = []
      abilities += %w[top_rope lead] if roped_climbing?
      abilities << "bouldering" if @trip.bouldering?
      abilities << "none" if roped_climbing? || @trip.bouldering?
      abilities
    end
  end

  def default_climbing_ability
    return "top_rope" if allowed_climbing_abilities.include?("top_rope")
    return "bouldering" if allowed_climbing_abilities.include?("bouldering")

    "none"
  end

  def roped_climbing?
    @trip.sport_climbing? || @trip.trad_climbing?
  end

  def truthy_param?(key)
    signup_params[key].to_s == "1"
  end

  def waiver_required?(minor_attributes)
    return true if minor_attributes.any?

    current_user.current_waiver_for_year(@trip.start_date.year).blank?
  end

  def waiver_acknowledged_at
    Time.zone.parse(signup_params[:waiver_acknowledged_at].to_s)
  rescue ArgumentError
    nil
  end

  def ensure_waiver_ready(minor_attributes:)
    @waiver_required = waiver_required?(minor_attributes)
    @waiver_signature = nil
    @waiver_acknowledged_at = nil
    return true unless @waiver_required

    @waiver_signature = WaiverSignatureData.new(signup_params[:waiver_signature_data])
    @waiver_acknowledged_at = waiver_acknowledged_at

    if @waiver_acknowledged_at.blank?
      redirect_to trip_path(@trip), alert: "Please agree to the waiver acknowledgement before tying in."
      false
    elsif !@waiver_signature.valid?
      redirect_to trip_path(@trip), alert: "Please sign the waiver before tying in."
      false
    else
      true
    end
  end

  def satisfy_waiver!(signup, minor_attributes)
    return if @waiver_signature.blank?

    waiver = WaiverCreator.new(
      user: current_user,
      signature: @waiver_signature,
      acknowledged_at: @waiver_acknowledged_at,
      request: request,
      trip: @trip,
      minor_attributes: minor_attributes
    ).create!

    signup.update!(
      waiver_acknowledged_at: waiver.waiver_acknowledged_at,
      waiver_acknowledgement_text: waiver.waiver_acknowledgement_text,
      waiver_acknowledgement_text_digest: waiver.waiver_acknowledgement_text_digest,
      waiver_signed_at: waiver.waiver_signed_at,
      waiver_signer_name: waiver.waiver_signer_name,
      waiver_text: waiver.waiver_text,
      waiver_text_digest: waiver.waiver_text_digest,
      waiver_signature_digest: waiver.waiver_signature_digest,
      waiver_ip_address: waiver.waiver_ip_address,
      waiver_user_agent: waiver.waiver_user_agent
    )
  end
end
