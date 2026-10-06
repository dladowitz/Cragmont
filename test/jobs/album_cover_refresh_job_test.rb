require "test_helper"

class AlbumCoverRefreshJobTest < ActiveJob::TestCase
  test "refreshes each public report album once and skips hidden reports" do
    LegacyTripReportImport.call
    trip = trips(:yosemite)
    trip.update!(start_date: Date.new(2026, 6, 12), end_date: Date.new(2026, 6, 15), auto_trip_report: true,
      photo_album_url: "https://photos.app.goo.gl/automatic")
    hidden = TripReport.find_by!(legacy_key: "2026-08-14-tuolumne")
    hidden.update!(hidden: true)
    travel_to Time.utc(2026, 10, 6)

    refreshed = []
    original = AlbumCover.method(:refresh)
    AlbumCover.define_singleton_method(:refresh) { |album_url| refreshed << album_url }
    AlbumCoverRefreshJob.perform_now

    assert_equal 22, refreshed.size
    assert_equal refreshed.uniq, refreshed
    assert_includes refreshed, "https://photos.app.goo.gl/automatic"
    assert_includes refreshed, "https://photos.app.goo.gl/eomxL1uoWFnRjkkJ6"
    refute_includes refreshed, hidden.published["album_url"]
  ensure
    AlbumCover.define_singleton_method(:refresh, original) if original
    travel_back
  end
end
