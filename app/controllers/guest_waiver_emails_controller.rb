class GuestWaiverEmailsController < ApplicationController
  before_action :require_login

  def create
    trip = Trip.published_for_public.find(params[:trip_id])
    guest_signup = trip.campsite_signups.confirmed.includes(:user, :campsite, guest_of_signup: :user).find(params[:id])

    if !guest_signup.guest? || guest_signup.guest_of_signup&.user_id != current_user.id
      respond_with_failure(trip, "Wow, that was a whipper. You can only email waiver links to guests you added.")
    elsif guest_signup.user.email.blank?
      respond_with_failure(trip, "Wow, that was a whipper. #{guest_signup.user.full_name} does not have an email address.")
    else
      GuestWaiverMailer.with(
        signup: guest_signup,
        primary_participant: current_user,
        waiver_url: guest_waiver_url(trip, guest_signup)
      ).needed.deliver_now
      message = "On belay! The waiver link was emailed to #{guest_signup.user.full_name}."
      respond_to do |format|
        format.html { redirect_to trip_path(trip, anchor: "campsite-#{guest_signup.campsite_id}"), notice: message }
        format.json { render json: { message: message, button_text: "Email sent" } }
      end
    end
  end

  private

  def respond_with_failure(trip, message)
    respond_to do |format|
      format.html { redirect_to trip_path(trip), alert: message }
      format.json { render json: { message: message, button_text: "Email failed" }, status: :unprocessable_entity }
    end
  end

  def guest_waiver_url(trip, signup)
    trip_url(trip, complete_signup: signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{signup.campsite_id}")
  end
end
