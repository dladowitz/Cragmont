class Admin::DashboardController < ApplicationController
  def index
    @trips = Trip.includes(:campsite_coordinator, { trip_signups: :trip_signup_minors }, campsites: :campground).order(start_date: :asc, name: :asc)
  end
end
