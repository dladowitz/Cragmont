class TripsController < ApplicationController
  before_action :set_trip, only: :show

  def index
    @trips = Trip.published_for_public.includes(:campsite_coordinator, :campsites)
  end

  def show
    @campsites = @trip.campsites.includes(:campground, campsite_signups: [ :user, :campsite_signup_minors ]).order(:arrival_date, :site_number)
    @current_signup = @trip.campsite_signups.includes(:campsite).find_by(user: current_user) if user_signed_in?
  end

  private

  def set_trip
    @trip = Trip.published.find(params[:id])
  end
end
