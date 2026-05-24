class TripsController < ApplicationController
  before_action :set_trip, only: :show

  def index
    @trips = Trip.published_for_public.includes(:campsite_coordinator, :campsites)
  end

  def show
    @campsites_by_campground = @trip.campsites.includes(:campground).order(:arrival_date, :site_number).group_by(&:campground)
    @confirmed_signups = @trip.trip_signups.confirmed.includes(:user).order(created_at: :asc)
    @current_signup = @trip.trip_signups.find_by(user: current_user) if user_signed_in?
  end

  private

  def set_trip
    @trip = Trip.published.find(params[:id])
  end
end
