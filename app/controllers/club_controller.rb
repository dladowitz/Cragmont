class ClubController < ApplicationController
  def about; end

  def membership; end

  def history; end

  def join_the_list; end

  def trip_reports
    @reports = TripReport.public_reports
  end
end
