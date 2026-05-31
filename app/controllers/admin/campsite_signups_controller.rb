class Admin::CampsiteSignupsController < ApplicationController
  def make_waitlist_eligible
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])

    if signup.confirmed?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is already confirmed for this trip."
    elsif signup.update(waitlist_eligible_at: Time.current)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} can now confirm an open campsite spot."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def revoke_waitlist_eligibility
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])

    if signup.confirmed?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is already confirmed for this trip."
    elsif signup.update(waitlist_eligible_at: nil)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} can no longer confirm an open campsite spot."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end
end
