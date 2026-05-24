class Admin::DashboardController < ApplicationController
  def index
    @trips = Trip.includes(:campsite_coordinator, campsites: :campground).order(start_date: :asc, name: :asc)
  end
end
