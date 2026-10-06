require "test_helper"

class Admin::TripReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @trip = trips(:yosemite)
    @trip.update!(campsite_coordinator: users(:sam), auto_trip_report: true, photo_album_url: "https://photos.app.goo.gl/sample")
    travel_to Time.utc(2026, 7, 1)
  end
  teardown { travel_back }

  test "report trip selectors distinguish repeat destinations by date" do
    log_in_as users(:alex)
    other = trips(:jtree)
    other.update!(name: @trip.name, end_date: other.start_date)

    [ new_admin_trip_report_url, new_admin_trip_report_url(standalone: 1) ].each do |url|
      get url
      assert_response :success
      assert_select "select[name='trip_report[trip_id]'] option[value='#{@trip.id}'], select[name='trip_id'] option[value='#{@trip.id}']",
        text: "Yosemite Valley Spring (June 12, 2026 to June 15, 2026)"
      assert_select "select[name='trip_report[trip_id]'] option[value='#{other.id}'], select[name='trip_id'] option[value='#{other.id}']",
        text: "Yosemite Valley Spring (December 04, 2026)"
    end
  end

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

  test "coordinator uploads a cover photo that stays private until published" do
    report = TripReport.for_trip(@trip)
    report.save!
    report.add_photos!([ report_image("2026-08-14-tuolumne.jpg") ], version: report.lock_version, actor: users(:sam))
    old_cover = report.draft["photos"].first["id"]
    log_in_as users(:sam)
    post cover_photo_admin_trip_report_url(report), params: { lock_version: report.lock_version, photo: report_image("2026-09-18-yosemite-valley.jpg") },
      headers: { "Accept" => "application/json" }
    assert_response :success
    new_cover = report.reload.draft["photos"].first["id"]
    assert_equal [ new_cover, old_cover ], report.draft["photos"].map { |photo| photo["id"] }
    assert_equal report.lock_version, response.parsed_body.dig("report", "lock_version")
    assert_equal "Published · unpublished changes", response.parsed_body.dig("report", "status")
    assert_match %r{data-photo-id="#{new_cover}".*Cover photo}m, response.parsed_body["photos_html"]
    assert_match "Make cover", response.parsed_body["photos_html"]
    assert_match photo_admin_trip_report_path(report, photo_id: new_cover), response.parsed_body["preview_html"]
    get photo_admin_trip_report_url(report, photo_id: new_cover)
    assert_response :success
    assert_match "no-store", response.headers["Cache-Control"]

    # Drafts never leak: visitors see the new cover only after publishing.
    delete session_url
    get photo_trip_report_url(report, photo_id: new_cover)
    assert_response :not_found
    get photo_admin_trip_report_url(report, photo_id: new_cover)
    assert_redirected_to new_session_path
    get trip_reports_url
    assert_select "#report-#{report.id} .club-report-gallery-placeholder"
    report.publish!(version: report.lock_version, actor: users(:sam))
    get photo_trip_report_url(report, photo_id: new_cover)
    assert_response :success
    get trip_reports_url
    assert_select "#report-#{report.id} .club-report-gallery img", count: 1
    assert_select "#report-#{report.id} .club-report-gallery img[src='#{photo_trip_report_path(report, photo_id: new_cover)}']"

    # Removing a photo from the draft keeps it public until the next publish.
    report.save_draft!({ photos: [] }, version: report.lock_version, actor: users(:sam))
    get photo_trip_report_url(report, photo_id: new_cover)
    assert_response :success
    report.publish!(version: report.lock_version, actor: users(:sam))
    get photo_trip_report_url(report, photo_id: new_cover)
    assert_response :not_found
  end

  test "cover uploads require permission one image and the latest version" do
    report = TripReport.for_trip(@trip)
    report.save!
    post cover_photo_admin_trip_report_url(report), params: { lock_version: report.lock_version, photo: report_image("2026-08-14-tuolumne.jpg") }
    assert_redirected_to new_session_path

    log_in_as users(:sam)
    stale_version = report.lock_version
    report.save_draft!({ body: "Another editor" }, version: report.lock_version, actor: users(:alex))
    post cover_photo_admin_trip_report_url(report), params: { lock_version: stale_version, photo: report_image("2026-08-14-tuolumne.jpg") },
      headers: { "Accept" => "application/json" }
    assert_response :conflict
    assert_match "Someone else changed this report", response.parsed_body["error"]

    [ { photo: [ report_image("2026-08-14-tuolumne.jpg"), report_image("2026-07-05-vent-five.jpg") ] }, { photo: "not-a-file" } ].each do |invalid|
      post cover_photo_admin_trip_report_url(report), params: invalid.merge(lock_version: report.reload.lock_version), headers: { "Accept" => "application/json" }
      assert_response :unprocessable_entity
      assert_equal "Choose one cover photo", response.parsed_body["error"]
    end

    @trip.update!(campsite_coordinator: users(:alex))
    post cover_photo_admin_trip_report_url(report), params: { lock_version: report.reload.lock_version, photo: report_image("2026-08-14-tuolumne.jpg") },
      headers: { "Accept" => "application/json" }
    assert_response :forbidden
    assert_empty report.reload.photos
    assert_empty report.draft["photos"]
  end

  test "cover upload replaces a legacy archive thumbnail on the report card" do
    LegacyTripReportImport.call
    report = TripReport.find_by!(legacy_key: "2026-09-18-yosemite-valley")
    album = report.published["album_url"]
    log_in_as users(:alex)
    post cover_photo_api_v1_trip_report_url(report), params: { lock_version: report.lock_version, photo: report_image("2026-08-14-tuolumne.jpg") }
    assert_response :success
    get trip_reports_url
    # Unpublished: the archive thumbnail still shows.
    assert_select "#report-#{report.id} .club-report-gallery img[src*='trip-reports/2026-09-18-yosemite-valley']", count: 1

    report.reload.publish!(version: report.lock_version, actor: users(:alex))
    cover = photo_trip_report_path(report, photo_id: report.published["photos"].first["id"])
    get trip_reports_url
    assert_select "#report-#{report.id} .club-report-gallery img", count: 1
    assert_select "#report-#{report.id} .club-report-gallery a[href='#{album}'][target='_blank'][rel='noopener'][aria-label*='opens in a new tab'] img[src='#{cover}']"
    assert_select "#report-#{report.id} a", text: "View photos", count: 0
    assert_select ".club-report-gallery img[src^='/assets/trip-reports/']", count: 21

    # The full report keeps the archive image beside the new cover.
    get trip_report_url(report)
    assert_select ".club-report-gallery img[src='#{cover}']", count: 1
    assert_select ".club-report-gallery img[src*='trip-reports/2026-09-18-yosemite-valley']", count: 1
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
    post cover_photo_api_v1_trip_report_url(report), params: { lock_version: report.lock_version, photo: upload }, headers: { "Accept" => "application/json" }
    assert_response :unprocessable_entity
    assert_match "Use JPEG, PNG, or WebP", response.parsed_body["error"]
    assert_empty report.reload.photos
    assert_equal @trip.name, report.draft["title"]
  end

  private

  def report_image(name)
    Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/trip-reports", name), "image/jpeg")
  end
end
