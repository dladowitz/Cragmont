class AlbumCoverRefreshJob < ApplicationJob
  # ponytail: one page fetch per public album each day; limit to recent trips if the archive grows large.
  def perform
    TripReport.public_reports.filter_map { |report| report.public_payload["album_url"].presence }.uniq
      .each { |album_url| AlbumCover.refresh(album_url) }
  end
end
