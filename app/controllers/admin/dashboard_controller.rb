class Admin::DashboardController < ApplicationController
  def index
    @trips = Trip.includes(campsites: :campground).order(start_date: :asc, name: :asc)
  end
end
