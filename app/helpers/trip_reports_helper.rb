module TripReportsHelper
  def report_trip_label(trip)
    dates = [ trip.start_date, trip.end_date ].uniq.map { |date| date.to_fs(:long) }.join(" to ")
    "#{trip.name} (#{dates})"
  end

  def public_report_path(report)
    report.persisted? ? trip_report_path(report) : trip_trip_report_path(report.trip)
  end

  def report_edit_path(report)
    report.persisted? ? edit_admin_trip_report_path(report) : new_admin_trip_report_path(trip_id: report.trip_id)
  end

  def report_photo_path(report, photo, preview: false)
    preview ? photo_admin_trip_report_path(report, photo_id: photo["id"]) : photo_trip_report_path(report, photo_id: photo["id"])
  end

  # The archive thumbnails are album covers the old site copied once, so the current cover replaces them.
  def report_cover_image(payload)
    @album_covers ||= AlbumCover.with_attached_image.index_by(&:album_url)
    @album_covers[payload["album_url"]]&.image.presence || report_legacy_image(payload)
  end

  def report_legacy_image(payload)
    image = payload["legacy_image"].to_s
    image if image.match?(%r{\Atrip-reports/[a-z0-9-]+\.jpg\z}) && Rails.root.join("app/assets/images", image).file?
  end
end
