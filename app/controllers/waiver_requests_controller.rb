class WaiverRequestsController < ApplicationController
  before_action :set_user

  def new
    @waiver_year = Date.current.year
  end

  def create
    signature = WaiverSignatureData.new(waiver_params[:waiver_signature_data])
    acknowledged_at = waiver_acknowledged_at
    minor_attributes = normalized_minor_attributes

    if signing_with_minors? && minor_attributes.empty?
      redirect_to waiver_request_path(params[:token]), alert: "Please enter minor information before signing the waiver."
    elsif minor_attributes.size > 2
      redirect_to waiver_request_path(params[:token]), alert: "Wow, that was a whipper. You can add up to 2 minors."
    elsif acknowledged_at.blank?
      redirect_to waiver_request_path(params[:token]), alert: "Please agree to the waiver acknowledgement before signing."
    elsif !signature.valid?
      redirect_to waiver_request_path(params[:token]), alert: "Please sign the waiver before submitting."
    else
      WaiverCreator.new(
        user: @user,
        signature: signature,
        acknowledged_at: acknowledged_at,
        request: request,
        waiver_year: Date.current.year,
        minor_attributes: minor_attributes
      ).create!
      redirect_to root_path, notice: "On belay! Your Cragmont waiver is signed."
    end
  rescue ActiveRecord::RecordInvalid => error
    redirect_to waiver_request_path(params[:token]), alert: "Wow, that was a whipper. #{error.record.errors.full_messages.to_sentence}."
  end

  private

  def set_user
    @user = User.find_signed!(params[:token], purpose: :standalone_waiver_request)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Wow, that was a whipper. That waiver link is invalid."
  end

  def waiver_params
    params.fetch(:waiver, {}).permit(
      :waiver_signature_data,
      :waiver_acknowledged_at,
      :with_minors,
      waiver_minors_attributes: %i[first_name last_name age relationship]
    )
  end

  def waiver_acknowledged_at
    Time.zone.parse(waiver_params[:waiver_acknowledged_at].to_s)
  rescue ArgumentError
    nil
  end

  def signing_with_minors?
    waiver_params[:with_minors] == "1"
  end

  def normalized_minor_attributes
    return [] unless signing_with_minors?

    raw_attributes = waiver_params[:waiver_minors_attributes] || {}
    raw_attributes.values.filter_map do |attributes|
      cleaned = attributes.to_h.transform_values { |value| value.to_s.strip }
      next if cleaned.values.all?(&:blank?)

      cleaned
    end
  end
end
