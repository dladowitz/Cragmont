require "test_helper"

class TripReportTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:yosemite)
    @trip.update!(start_date: Date.new(2026, 6, 12), end_date: Date.new(2026, 6, 15),
      auto_trip_report: true, photo_album_url: "https://photos.app.goo.gl/sample")
    travel_to Time.utc(2026, 6, 16, 8)
  end

  teardown { travel_back }

  test "automatic album appears only after the final Pacific date" do
    travel_to Time.utc(2026, 6, 16, 6, 59)
    assert_nil TripReport.for_trip(@trip).public_payload
    travel_to Time.utc(2026, 6, 16, 7, 1)
    assert_equal @trip.photo_album_url, TripReport.for_trip(@trip).public_payload["album_url"]
    assert_no_difference "TripReport.count" do
      TripReport.public_reports
    end
  end

  test "automatic reports honor overnight outing end time" do
    @trip.assign_attributes(trip_type: "gym_outing", participant_capacity: 8,
      start_date: Date.new(2026, 6, 15), end_date: Date.new(2026, 6, 15), meeting_time: "22:00", end_time: "02:00")
    refute @trip.report_ended?(Time.utc(2026, 6, 16, 8))
    assert @trip.report_ended?(Time.utc(2026, 6, 16, 9, 1))
  end

  test "private albums invalid links drafts and deleted trips are excluded" do
    [ "https://photos.app.goo.gl.evil.test/a", "http://photos.app.goo.gl/a", "https://photos.app.goo.gl@evil.test/a", "javascript:alert(1)", "https://photos.app.goo.gl/" ].each do |url|
      @trip.photo_album_url = url
      assert_nil TripReport.for_trip(@trip).public_payload
    end
    @trip.photo_album_url = "https://photos.google.com/share/sample"
    @trip.auto_trip_report = false
    assert_nil TripReport.for_trip(@trip).public_payload
    @trip.auto_trip_report = true
    @trip.status = "draft"
    assert_nil TripReport.for_trip(@trip).public_payload
    @trip.status = "published"
    @trip.deleted_at = Time.current
    assert_nil TripReport.for_trip(@trip).public_payload
  end

  test "draft publish edit and hide preserve the public snapshot" do
    report = TripReport.for_trip(@trip)
    report.save_draft!({ body: "Private story", title: "Private title" }, version: 0, actor: users(:alex))
    assert_equal @trip.name, report.public_payload["title"]
    assert_empty report.public_payload["body"]
    assert_equal "Published · unpublished changes", report.display_status
    report.publish!(version: report.lock_version, actor: users(:alex))
    assert_equal "Private story", report.public_payload["body"]
    report.save_draft!({ body: "Unfinished edits" }, version: report.lock_version, actor: users(:alex))
    assert_equal "Private story", report.public_payload["body"]
    report.hide!(version: report.lock_version, actor: users(:alex))
    assert_nil report.public_payload
    assert_nil TripReport.for_trip(@trip.reload).public_payload
    report.save_draft!({ body: "Completed edits" }, version: report.lock_version, actor: users(:alex))
    assert_nil report.public_payload
    report.publish!(version: report.lock_version, actor: users(:alex))
    assert_equal "Completed edits", report.public_payload["body"]
    assert_equal 1, TripReport.public_reports.count { |item| item.trip_id == @trip.id }
  end

  test "stale saves and publishing cannot overwrite other editors" do
    report = TripReport.for_trip(@trip)
    report.save!
    stale = TripReport.find(report.id)
    report.save_draft!({ body: "Newer edit" }, version: report.lock_version, actor: users(:alex))
    assert_raises(ActiveRecord::StaleObjectError) { stale.save_draft!({ body: "Old edit" }, version: stale.lock_version, actor: users(:alex)) }
    assert_raises(ActiveRecord::StaleObjectError) { report.publish!(version: 0, actor: users(:alex)) }
    assert_equal "Newer edit", report.reload.draft["body"]
    assert_empty report.published
  end

  test "one report per trip and photos cannot come from another report" do
    report = TripReport.for_trip(@trip)
    report.save!
    duplicate = TripReport.new(trip: @trip, draft: report.draft)
    refute duplicate.valid?
    report.draft = report.draft.merge("photos" => [ { "id" => 123456, "caption" => "not ours" } ])
    refute report.valid?
  end

  test "archive import is repeatable and preserves edited reports" do
    LegacyTripReportImport.call
    original = TripReport.find_by!(legacy_key: "2026-08-22-snowshed-tahoe")
    assert_equal "Nat Baykova", original.draft["byline"]
    assert_match "Vertical Pursuits", original.draft["body"]
    original.update!(draft: original.draft.merge("title" => "Edited title"))
    assert_no_difference "TripReport.count" do
      LegacyTripReportImport.call
    end
    assert_equal "Edited title", original.reload.draft["title"]
    assert_equal 22, TripReport.where.not(legacy_key: nil).count
  end
end
