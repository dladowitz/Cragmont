class TripReportsController < ApplicationController
  def show
    @report = params[:trip_id].present? ? TripReport.for_trip(Trip.find(params[:trip_id])) : TripReport.find(params[:id])
    @payload = @report.public_payload
    raise ActiveRecord::RecordNotFound if @payload.blank?
  end

  def photo
    report = TripReport.find(params[:id])
    payload = report.public_payload
    raise ActiveRecord::RecordNotFound unless payload && Array(payload["photos"]).any? { |photo| photo["id"].to_s == params[:photo_id] }
    attachment = report.photos.find(params[:photo_id])
    response.headers["Cache-Control"] = "private, no-store"
    send_data attachment.variant(resize_to_limit: [ 1600, 1600 ], saver: { strip: true }).processed.download,
      type: attachment.content_type, disposition: "inline"
  end
end
