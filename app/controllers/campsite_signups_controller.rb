require "digest"
require "stringio"

class CampsiteSignupsController < ApplicationController
  before_action :require_login

  def create
    trip = Trip.published.find(params[:trip_id])
    campsite = trip.campsites.find(params[:campsite_id])
    signup = trip.campsite_signups.find_or_initialize_by(user: current_user)

    if signup.persisted? && confirming_waitlist?
      confirm_waitlisted_signup(trip, campsite, signup)
    elsif signup.persisted? && signing_up_from_waitlist?
      confirm_open_campsite_signup_from_waitlist(trip, campsite, signup)
    elsif signup.persisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif joining_waitlist?
      join_waitlist(trip, campsite, signup)
    else
      create_confirmed_signup(trip, campsite, signup)
    end
  end

  def destroy
    trip = Trip.published.find(params[:trip_id])
    campsite = trip.campsites.find(params[:campsite_id])
    signup = trip.campsite_signups.find_by(user: current_user)

    if signup.blank?
      redirect_to trip_path(trip), alert: "You are not signed up for this trip.", status: :see_other
    elsif signup.confirmed? && signup.campsite != campsite
      redirect_to trip_path(trip), alert: "You are not signed up for this campsite.", status: :see_other
    else
      removing_waitlist_signup = signup.waitlisted?
      campsite.lock_signups! if signup.confirmed? && campsite.capacity_full?
      signup.destroy
      trip.mark_next_waitlisted_signup_eligible! unless removing_waitlist_signup

      notice = removing_waitlist_signup ? "You have been removed from the waitlist." : "You have been removed from this campsite."
      redirect_to trip_path(trip), notice: notice, status: :see_other
    end
  end

  private

  def join_waitlist(trip, campsite, signup)
    minor_attributes = normalized_minor_attributes

    if !campsite.waitlist_signup_required?
      redirect_to trip_path(trip), alert: "This campsite still has space. Please sign up for the campsite directly."
    elsif signing_up_with_minors? && minor_attributes.empty?
      redirect_to trip_path(trip), alert: "Please enter minor information before joining the waitlist."
    elsif create_waitlist_signup(signup, minor_attributes)
      campsite.lock_signups! if campsite.capacity_full?
      redirect_to trip_path(trip), notice: "You have been added to the waitlist for this trip."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def create_confirmed_signup(trip, campsite, signup)
    minor_attributes = normalized_minor_attributes

    if !campsite.direct_signup_available?
      redirect_to trip_path(trip), alert: "This campsite is using the waitlist."
    elsif signing_up_with_minors? && minor_attributes.empty?
      redirect_to trip_path(trip), alert: "Please enter minor information before signing up."
    elsif !campsite_has_room_for?(campsite, minor_attributes)
      join_waitlist_from_full_party(trip, signup, minor_attributes)
    else
      create_signup_with_confirmation(trip, campsite, signup, minor_attributes)
    end
  end

  def join_waitlist_from_full_party(trip, signup, minor_attributes)
    if create_waitlist_signup(signup, minor_attributes)
      redirect_to trip_path(trip), notice: "There is not enough space for your party, so you have been added to the waitlist for this trip."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def create_signup_with_confirmation(trip, campsite, signup, minor_attributes)
    signature = WaiverSignatureData.new(signup_params[:waiver_signature_data])
    acknowledged_at = waiver_acknowledged_at

    if acknowledged_at.blank?
      redirect_to trip_path(trip), alert: "Please agree to the waiver acknowledgement before signing up."
    elsif !signature.valid?
      redirect_to trip_path(trip), alert: "Please sign the waiver before signing up."
    elsif create_signup_with_waiver(signup, campsite, signature, acknowledged_at, minor_attributes)
      redirect_to trip_path(trip), notice: "You are confirmed for this campsite."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def confirm_waitlisted_signup(trip, campsite, signup)
    signature = WaiverSignatureData.new(signup_params[:waiver_signature_data])
    acknowledged_at = waiver_acknowledged_at

    if !signup.waitlisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif !signup.waitlist_eligible?
      redirect_to trip_path(trip), alert: "You are not eligible to confirm a spot yet."
    elsif !campsite.available_for_waitlist_confirmation?(signup)
      redirect_to trip_path(trip), alert: "That campsite spot is no longer available."
    elsif acknowledged_at.blank?
      redirect_to trip_path(trip), alert: "Please agree to the waiver acknowledgement before confirming your spot."
    elsif !signature.valid?
      redirect_to trip_path(trip), alert: "Please sign the waiver before confirming your spot."
    elsif confirm_waitlist_signup_with_waiver(signup, campsite, signature, acknowledged_at)
      redirect_to trip_path(trip), notice: "You are confirmed for this campsite."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def confirm_open_campsite_signup_from_waitlist(trip, campsite, signup)
    signature = WaiverSignatureData.new(signup_params[:waiver_signature_data])
    acknowledged_at = waiver_acknowledged_at

    if !signup.waitlisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif !campsite.direct_signup_available?
      redirect_to trip_path(trip), alert: "This campsite is using the waitlist."
    elsif !campsite_has_room_for_waitlisted_signup?(campsite, signup)
      redirect_to trip_path(trip), alert: "There is not enough space for your party at this campsite."
    elsif acknowledged_at.blank?
      redirect_to trip_path(trip), alert: "Please agree to the waiver acknowledgement before signing up."
    elsif !signature.valid?
      redirect_to trip_path(trip), alert: "Please sign the waiver before signing up."
    elsif confirm_open_campsite_signup_with_waiver(signup, campsite, signature, acknowledged_at)
      redirect_to trip_path(trip), notice: "You are confirmed for this campsite."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def signup_params
    params.fetch(:campsite_signup, {}).permit(
      :intent,
      :signup_kind,
      :arrival_date,
      :checkout_date,
      :waiver_signature_data,
      :waiver_acknowledged_at,
      campsite_signup_minors_attributes: %i[first_name last_name age relationship]
    )
  end

  def attendance_params
    signup_params.slice(:arrival_date, :checkout_date)
  end

  def joining_waitlist?
    signup_params[:intent] == "join_waitlist"
  end

  def confirming_waitlist?
    signup_params[:intent] == "confirm_waitlist"
  end

  def signing_up_from_waitlist?
    signup_params[:intent] == "waitlist_direct_signup"
  end

  def waiver_acknowledged_at
    Time.zone.parse(signup_params[:waiver_acknowledged_at].to_s)
  rescue ArgumentError
    nil
  end

  def signing_up_with_minors?
    signup_params[:signup_kind] == "with_minors"
  end

  def normalized_minor_attributes
    return [] unless signing_up_with_minors?

    raw_attributes = signup_params[:campsite_signup_minors_attributes] || {}
    raw_attributes.values.filter_map do |attributes|
      cleaned = attributes.to_h.transform_values { |value| value.to_s.strip }
      next if cleaned.values.all?(&:blank?)

      cleaned
    end
  end

  def campsite_has_room_for?(campsite, minor_attributes)
    capacity_count = 1 + minor_attributes.count { |attributes| attributes[:age].to_i >= SiteSetting.current.uncounted_minor_age_limit }
    campsite.available_participant_capacity >= capacity_count
  end

  def campsite_has_room_for_waitlisted_signup?(campsite, signup)
    campsite.available_participant_capacity >= signup.capacity_count
  end

  def create_waitlist_signup(signup, minor_attributes)
    CampsiteSignup.transaction do
      signup.status = "waitlisted"
      minor_attributes.each { |attributes| signup.campsite_signup_minors.build(attributes) }
      signup.save!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def create_signup_with_waiver(signup, campsite, signature, acknowledged_at, minor_attributes)
    CampsiteSignup.transaction do
      campsite.lock!
      signup.assign_attributes(attendance_params.merge(campsite: campsite, status: "confirmed"))
      minor_attributes.each { |attributes| signup.campsite_signup_minors.build(attributes) }
      signup.save!
      attach_waiver!(signup, signature, acknowledged_at)
      campsite.lock_signups_if_full!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def confirm_waitlist_signup_with_waiver(signup, campsite, signature, acknowledged_at)
    confirmed = false

    CampsiteSignup.transaction do
      signup.lock!
      campsite.lock!

      unless campsite.available_for_waitlist_confirmation?(signup)
        signup.errors.add(:base, "That campsite spot is no longer available")
        raise ActiveRecord::Rollback
      end

      signup.assign_attributes(attendance_params.merge(campsite: campsite, status: "confirmed"))
      signup.save!
      attach_waiver!(signup, signature, acknowledged_at)
      campsite.lock_signups_if_full!
      confirmed = true
    end

    confirmed
  rescue ActiveRecord::RecordInvalid
    false
  end

  def confirm_open_campsite_signup_with_waiver(signup, campsite, signature, acknowledged_at)
    confirmed = false

    CampsiteSignup.transaction do
      signup.lock!
      campsite.lock!

      unless campsite.direct_signup_available? && campsite_has_room_for_waitlisted_signup?(campsite, signup)
        signup.errors.add(:base, "That campsite spot is no longer available")
        raise ActiveRecord::Rollback
      end

      signup.assign_attributes(attendance_params.merge(
        campsite: campsite,
        status: "confirmed",
        waitlist_eligible_at: nil
      ))
      signup.save!
      attach_waiver!(signup, signature, acknowledged_at)
      campsite.lock_signups_if_full!
      confirmed = true
    end

    confirmed
  rescue ActiveRecord::RecordInvalid
    false
  end

  def attach_waiver!(signup, signature, acknowledged_at)
    signed_at = Time.current
    waiver_text = TripSignupWaiver.text
    acknowledgement_text = TripSignupWaiver.acknowledgement_text

    signup.update!(
      waiver_acknowledged_at: acknowledged_at,
      waiver_acknowledgement_text: acknowledgement_text,
      waiver_acknowledgement_text_digest: ::Digest::SHA256.hexdigest(acknowledgement_text),
      waiver_signed_at: signed_at,
      waiver_signer_name: current_user.full_name,
      waiver_text: waiver_text,
      waiver_text_digest: ::Digest::SHA256.hexdigest(waiver_text),
      waiver_signature_digest: signature.digest,
      waiver_ip_address: request.remote_ip,
      waiver_user_agent: request.user_agent
    )

    signup.waiver_signature_image.attach(
      io: StringIO.new(signature.bytes),
      filename: "campsite-signup-#{signup.id}-signature.png",
      content_type: "image/png"
    )

    signup.waiver_document.attach(
      io: StringIO.new(CampsiteSignupWaiverPdf.new(campsite_signup: signup, signature_png: signature.bytes).render),
      filename: signup.waiver_document_filename,
      content_type: "application/pdf"
    )
  end
end
