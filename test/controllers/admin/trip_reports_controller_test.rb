require "test_helper"

class Admin::TripReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @trip = trips(:yosemite)
    @trip.update!(campsite_coordinator: users(:sam), auto_trip_report: true, photo_album_url: "https://photos.app.goo.gl/sample")
    travel_to Time.utc(2026, 7, 1)
  end
  teardown { travel_back }

  test "coordinator can discover editor create and edit own trip report" do
    log_in_as users(:sam)
    get admin_trip_reports_url
    assert_response :success
    get new_admin_trip_report_url
    assert_response :success
    get new_admin_trip_report_url(trip_id: @trip.id)
    assert_response :success
    assert_select "input[name='trip_report[title]'][value='#{@trip.name}']"
    assert_select "a[href='#{admin_trip_reports_path}']", minimum: 1
    post api_v1_trip_reports_url, params: { trip_report: { trip_id: @trip.id, body: "A private draft" } }, as: :json
    assert_response :created
    report = TripReport.last
    assert_equal "A private draft", report.draft["body"]
    patch api_v1_trip_report_url(report), params: { trip_report: { body: "Updated draft", lock_version: report.lock_version } }, as: :json
    assert_response :success
    assert_equal "Updated draft", report.reload.draft["body"]
    assert_no_difference "TripReport.count" do
      post api_v1_trip_reports_url, params: { trip_report: { trip_id: @trip.id } }, as: :json
    end
    assert_response :conflict
  end

  test "coordinator cannot edit others standalone legacy or relink reports" do
    other = TripReport.for_trip(trips(:jtree))
    other.save!
    own = TripReport.for_trip(@trip)
    own.save!
    log_in_as users(:sam)
    get api_v1_trip_report_url(other), as: :json
    assert_response :forbidden
    patch api_v1_trip_report_url(other), params: { trip_report: { body: "Intrusion", lock_version: 0 } }, as: :json
    assert_response :forbidden
    post api_v1_trip_reports_url, params: { trip_report: { title: "Standalone" } }, as: :json
    assert_response :forbidden
    patch api_v1_trip_report_url(own), params: { trip_report: { trip_id: trips(:jtree).id, lock_version: 0 } }, as: :json
    assert_response :forbidden
    get api_v1_trip_reports_url, as: :json
    assert_response :success
    refute_includes response.parsed_body["reports"].map { |item| item["id"] }, other.id
  end

  test "public album stays public without exposing draft then hide stays hidden" do
    report = TripReport.for_trip(@trip)
    report.save_draft!({ body: "SECRET DRAFT" }, version: 0, actor: users(:sam))
    get trip_report_url(report)
    assert_response :success
    refute_includes response.body, "SECRET DRAFT"
    log_in_as users(:sam)
    patch publish_api_v1_trip_report_url(report), params: { lock_version: report.lock_version }, as: :json
    assert_response :success
    delete session_url
    get trip_report_url(report)
    assert_includes response.body, "SECRET DRAFT"
    log_in_as users(:sam)
    patch hide_api_v1_trip_report_url(report), params: { lock_version: report.reload.lock_version }, as: :json
    assert_response :success
    delete session_url
    get trip_report_url(report)
    assert_response :not_found
    get trip_reports_url
    refute_includes response.body, "SECRET DRAFT"
  end

  test "stale API returns conflict and unknown fields cannot publish" do
    report = TripReport.for_trip(@trip)
    report.save!
    log_in_as users(:sam)
    patch api_v1_trip_report_url(report), params: { trip_report: { body: "First", lock_version: 0 } }, as: :json
    assert_response :success
    patch api_v1_trip_report_url(report), params: { trip_report: { body: "Stale", lock_version: 0 } }, as: :json
    assert_response :conflict
    assert_equal "First", report.reload.draft["body"]
    patch api_v1_trip_report_url(report), params: { trip_report: { published: { body: "Bypass" }, lock_version: report.lock_version } }, as: :json
    assert_response :unprocessable_entity
    assert_empty report.reload.published
  end

  test "uploaded draft photos require permission and public photos follow published snapshot" do
    report = TripReport.for_trip(@trip)
    report.save!
    log_in_as users(:sam)
    upload = Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/trip-reports/2026-08-14-tuolumne.jpg"), "image/jpeg")
    post photos_admin_trip_report_url(report), params: { lock_version: report.lock_version, photos: [ upload ] }, headers: { "Accept" => "application/json" }
    assert_response :success
    report.reload
    photo = report.draft["photos"].first
    assert photo
    get photo_admin_trip_report_url(report, photo_id: photo["id"])
    assert_response :success
    assert_match "no-store", response.headers["Cache-Control"]
    delete session_url
    get photo_trip_report_url(report, photo_id: photo["id"])
    assert_response :not_found
    get photo_admin_trip_report_url(report, photo_id: photo["id"])
    assert_redirected_to new_session_path
    report.publish!(version: report.lock_version, actor: users(:sam))
    get photo_trip_report_url(report, photo_id: photo["id"])
    assert_response :success
    report.save_draft!({ photos: [] }, version: report.lock_version, actor: users(:sam))
    get photo_trip_report_url(report, photo_id: photo["id"])
    assert_response :success
    report.publish!(version: report.lock_version, actor: users(:sam))
    get photo_trip_report_url(report, photo_id: photo["id"])
    assert_response :not_found
  end

  test "admin can edit a legacy report and link it to a trip" do
    LegacyTripReportImport.call
    report = TripReport.find_by!(legacy_key: "2026-08-14-tuolumne")
    log_in_as users(:alex)
    patch api_v1_trip_report_url(report), params: { trip_report: { trip_id: @trip.id, title: "Corrected title", lock_version: report.lock_version } }, as: :json
    assert_response :success
    assert_equal @trip.id, report.reload.trip_id
    assert_equal "Corrected title", report.draft["title"]
    refute_equal "Corrected title", report.published["title"]
    assert report.draft["legacy_image"].present?
  end

  test "non coordinators and finance-only admins cannot manage reports" do
    @trip.update!(campsite_coordinator: users(:alex))
    assign_role(users(:sam), :finance_admin)
    log_in_as users(:sam)
    get api_v1_trip_reports_url, as: :json
    assert_response :forbidden
    get new_admin_trip_report_url(trip_id: @trip.id), as: :json
    assert_response :forbidden
  end

  test "report writes require the signed in browser CSRF token" do
    log_in_as users(:sam)
    old_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get admin_trip_reports_url
    csrf = css_select('meta[name="csrf-token"]').first["content"]
    post api_v1_trip_reports_url, params: { trip_report: { trip_id: @trip.id } }, as: :json
    assert_response :unprocessable_entity
    post api_v1_trip_reports_url, params: { trip_report: { trip_id: @trip.id } }, headers: { "X-CSRF-Token" => csrf }, as: :json
    assert_response :created
  ensure
    ActionController::Base.allow_forgery_protection = old_setting
  end

  test "malformed data and non images cannot change a report" do
    report = TripReport.for_trip(@trip)
    report.save!
    log_in_as users(:sam)
    post api_v1_trip_reports_url, params: { trip_report: { trip_id: [ @trip.id ] } }, as: :json
    assert_response :unprocessable_entity
    get api_v1_trip_reports_url, params: { q: [ "invalid" ] }, as: :json
    assert_response :unprocessable_entity
    [ { photos: "wrong" }, { title: 123 }, { photos: [ { id: 1, extra: true } ] } ].each do |invalid|
      patch api_v1_trip_report_url(report), params: { trip_report: invalid.merge(lock_version: report.lock_version) }, as: :json
      assert_response :unprocessable_entity
    end
    upload = Rack::Test::UploadedFile.new(Rails.root.join("README.md"), "image/jpeg")
    post photos_api_v1_trip_report_url(report), params: { lock_version: report.lock_version, photos: [ upload ] }, headers: { "Accept" => "application/json" }
    assert_response :unprocessable_entity
    assert_empty report.reload.photos
    assert_equal @trip.name, report.draft["title"]
  end
end
