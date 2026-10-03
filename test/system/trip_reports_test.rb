require "application_system_test_case"

class TripReportsTest < ApplicationSystemTestCase
  setup do
    @old_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @trip = trips(:yosemite)
    @trip.update!(campsite_coordinator: users(:sam), auto_trip_report: true,
      photo_album_url: "https://photos.app.goo.gl/sample")
    travel_to Time.utc(2026, 7, 1)
    visit new_session_path
    fill_in "Email", with: users(:sam).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"
    visit new_admin_trip_report_path(trip_id: @trip.id)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @old_forgery_protection
    travel_back
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "coordinator autosaves previews and publishes without leaking draft changes" do
    fill_in "Story (optional)", with: "A brilliant day on granite."
    assert_selector "[data-report-editor-target='status']", text: "Saved at", wait: 5
    report = TripReport.find_by!(trip: @trip)
    assert_empty report.public_payload["body"]

    [ [ 1440, 900 ], [ 768, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width < 901)
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
      if width <= 900
        field = find_field("Title").native.rect
        [ ".report-editor-navigation", ".report-editor-tabs" ].each do |selector|
          row = find(selector)
          buttons = row.all(".button", count: 2)
          assert_in_delta field.x, buttons.first.native.rect.x, 1
          assert_in_delta field.x + field.width, buttons.last.native.rect.x + buttons.last.native.rect.width, 1
          assert_in_delta buttons.first.native.rect.width, buttons.last.native.rect.width, 1
          assert_in_delta buttons.first.native.rect.y, buttons.last.native.rect.y, 1
        end
        find(".report-editor").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
        save_screenshot(Rails.root.join("tmp/screenshots/report-editor-buttons-#{width}.png"))
        find_button("Preview", exact: true).send_keys(:enter)
        assert_selector ".report-preview", text: "A brilliant day on granite.", wait: 5
        assert_no_selector ".report-write"
        find_button("Write", exact: true).send_keys(:enter)
      end
      assert_selector "textarea"
    end
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    click_button "Publish report", exact: true
    assert_current_path trip_report_path(report)
    assert_selector ".club-report", text: report.reload.public_payload["body"]
    visit edit_admin_trip_report_path(report)
    assert_equal "A brilliant day on granite.", report.reload.public_payload["body"]
    fill_in "Story (optional)", with: "Unfinished edits are private."
    click_button "Save draft", exact: true
    assert_selector "[data-report-editor-target='publication']", text: "unpublished changes"
    assert_equal "A brilliant day on granite.", report.reload.public_payload["body"]
    visit current_path
    assert_field "Story (optional)", with: "Unfinished edits are private."
    accept_confirm { click_button "Hide report", exact: true }
    assert_selector "[data-report-editor-target='status']", text: "Report hidden"
    assert_nil report.reload.public_payload
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "preview leaves clean reports unchanged and saves pending edits" do
    report = TripReport.for_trip(@trip)
    report.save_draft!({ body: "Original story." }, version: 0, actor: users(:alex))
    visit edit_admin_trip_report_path(report)
    page.driver.browser.manage.window.resize_to(390, 844)

    original = report.attributes
    click_button "Preview", exact: true
    assert_selector ".report-preview", text: "Original story."
    assert_selector "[data-report-editor-target='status']", text: "Drafts are private."
    assert_equal original, report.reload.attributes

    click_button "Write", exact: true
    fill_in "Story (optional)", with: "New private draft."
    click_button "Preview", exact: true
    assert_selector ".report-preview", text: "New private draft."
    assert_selector "[data-report-editor-target='status']", text: "Saved at"
    assert_equal "New private draft.", report.reload.draft["body"]
    assert_empty report.public_payload["body"]
  end

  test "preview initializes an untouched new linked report" do
    page.driver.browser.manage.window.resize_to(390, 844)
    assert_difference "TripReport.count", 1 do
      click_button "Preview", exact: true
      assert_selector ".report-preview", text: @trip.name
      assert_selector "[data-report-editor-target='status']", text: "Saved at"
    end
    assert_current_path edit_admin_trip_report_path(TripReport.find_by!(trip: @trip))
  end

  test "existing photos and conflict handling remain available without new uploads" do
    report = TripReport.for_trip(@trip)
    report.save!
    uploads = %w[2026-08-14-tuolumne.jpg 2026-08-22-snowshed-tahoe.jpg].map do |name|
      Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/trip-reports", name), "image/jpeg")
    end
    report.add_photos!(uploads, version: report.lock_version, actor: users(:sam))
    visit edit_admin_trip_report_path(report)
    assert_no_selector "input[type='file']"
    assert_selector ".report-edit-photo", count: 2, wait: 10
    rows = all(".report-edit-photo")
    first_id = rows.first["data-photo-id"]
    second_id = rows.last["data-photo-id"]
    rows.last.fill_in "Caption / image description", with: "Granite slabs"
    rows.last.find_button("Move to first", exact: true).send_keys(:enter)
    assert_selector ".report-edit-photo:first-child[data-photo-id='#{second_id}']"
    click_button "Save draft", exact: true
    assert_selector "[data-report-editor-target='status']", text: "Saved at", wait: 5
    report = TripReport.find_by!(trip: @trip)
    assert_equal [ second_id.to_i, first_id.to_i ], report.draft["photos"].map { |photo| photo["id"] }
    assert_equal "Granite slabs", report.draft["photos"].first["caption"]
    click_button "Publish report", exact: true
    assert_current_path trip_report_path(report)
    assert_selector ".club-report", text: report.reload.public_payload["body"]
    visit edit_admin_trip_report_path(report)

    report.reload.save_draft!({ body: "Another editor's saved work" }, version: report.lock_version, actor: users(:alex))
    fill_in "Story (optional)", with: "Keep my unsaved text"
    click_button "Save draft", exact: true
    assert_selector "[role='alert']", text: "Someone else changed this report"
    assert_field "Story (optional)", with: "Keep my unsaved text"
    assert_equal "Another editor's saved work", report.reload.draft["body"]
  end
end
