class TripSignupsController < ApplicationController
  before_action :require_login

  def create
    trip = Trip.published.find(params[:trip_id])
    signup = trip.trip_signups.find_or_initialize_by(user: current_user)

    if signup.persisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif signup.save
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
end
