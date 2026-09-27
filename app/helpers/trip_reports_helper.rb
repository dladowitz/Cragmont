module TripReportsHelper
  def public_report_path(report)
    report.persisted? ? trip_report_path(report) : trip_trip_report_path(report.trip)
  end

  def report_edit_path(report)
    report.persisted? ? edit_admin_trip_report_path(report) : new_admin_trip_report_path(trip_id: report.trip_id)
  end

  def report_photo_path(report, photo, preview: false)
    preview ? photo_admin_trip_report_path(report, photo_id: photo["id"]) : photo_trip_report_path(report, photo_id: photo["id"])
  end

  def report_legacy_image(payload)
    image = payload["legacy_image"].to_s
    image if image.match?(%r{\Atrip-reports/[a-z0-9-]+\.jpg\z}) && Rails.root.join("app/assets/images", image).file?
  end
end
