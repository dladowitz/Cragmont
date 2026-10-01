class TripCalendarsController < ApplicationController
  def index
    send_calendar(Trip.visible_for_public.order(:start_date, :id), "cragmont-events.ics")
  end

  def show
    trip = Trip.visible_for_public.find(params[:id])
    send_calendar([ trip ], "cragmont-trip-#{trip.id}.ics")
  end

  private

  def send_calendar(trips, filename)
    url_options = { host: request.host_with_port, protocol: request.protocol }.merge(Rails.application.routes.default_url_options)
    send_data TripCalendar.new(trips, url_options: url_options).render,
      type: "text/calendar; charset=utf-8", disposition: "attachment", filename: filename
  end
end
