require "digest"
require "stringio"

class TripSignupsController < ApplicationController
  before_action :require_login

  def create
    trip = Trip.published.find(params[:trip_id])
    signup = trip.trip_signups.find_or_initialize_by(user: current_user)
    signature = WaiverSignatureData.new(signup_params[:waiver_signature_data])
    acknowledged_at = waiver_acknowledged_at

    if signup.persisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif acknowledged_at.blank?
      redirect_to trip_path(trip), alert: "Please agree to the waiver acknowledgement before signing up."
    elsif !signature.valid?
      redirect_to trip_path(trip), alert: "Please sign the waiver before signing up."
    elsif create_signup_with_waiver(signup, signature, acknowledged_at)
      redirect_to trip_path(trip), notice: signup.confirmed? ? "You are confirmed for this trip." : "You have been added to the waitlist."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def destroy
    trip = Trip.published.find(params[:trip_id])
    signup = trip.trip_signups.find_by(user: current_user)

    if signup.present?
      signup.destroy
      redirect_to trip_path(trip), notice: "You have been removed from this trip.", status: :see_other
    else
      redirect_to trip_path(trip), alert: "You are not signed up for this trip.", status: :see_other
    end
  end

  private

  def signup_params
    params.fetch(:trip_signup, {}).permit(:waiver_signature_data, :waiver_acknowledged_at)
  end

  def waiver_acknowledged_at
    Time.zone.parse(signup_params[:waiver_acknowledged_at].to_s)
  rescue ArgumentError
    nil
  end

  def create_signup_with_waiver(signup, signature, acknowledged_at)
    TripSignup.transaction do
      signup.save!
      attach_waiver!(signup, signature, acknowledged_at)
    end
    true
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
      filename: "trip-signup-#{signup.id}-signature.png",
      content_type: "image/png"
    )

    signup.waiver_document.attach(
      io: StringIO.new(TripSignupWaiverPdf.new(trip_signup: signup, signature_png: signature.bytes).render),
      filename: signup.waiver_document_filename,
      content_type: "application/pdf"
    )
  end
end
