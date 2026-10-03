require "application_system_test_case"
require "json"

# Opt-in before/after capture against the same fixtures, browser, and viewport.
# See docs/ui-components.md for recording and comparison commands.
class UiComponentParityTest < ApplicationSystemTestCase
  test "capture current public and admin UI for component parity" do
    skip "Set UI_PARITY_OUTPUT to capture a visual baseline" unless ENV["UI_PARITY_OUTPUT"].present?

    travel_to Time.zone.local(2026, 10, 3, 12)
    LegacyTripReportImport.call
    # Equal-date legacy entries otherwise inherit PostgreSQL's unspecified row order.
    used_dates = Set.new
    TripReport.where.not(legacy_key: nil).order(:legacy_key).each do |legacy|
      date = Date.iso8601(legacy.draft.fetch("start_date"))
      date += 1 while used_dates.include?(date)
      used_dates << date
      legacy.update_columns(draft: legacy.draft.merge("start_date" => date.to_s), published: legacy.published.merge("start_date" => date.to_s))
    end
    trips(:jtree).update!(status: "archived")
    trips(:yosemite).update!(auto_trip_report: true, photo_album_url: "https://photos.app.goo.gl/example")
    report = TripReport.for_trip(trips(:yosemite))
    report.save!
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    variants = {
      "day" => { trip_type: "day_trip", meeting_time: "08:30", meeting_location: "Parking lot", meeting_location_url: "https://maps.google.com/?q=Castle+Rock", late_arrival_instructions: "Meet at the main wall.", climbing_types: [ "sport" ] },
      "gym" => { trip_type: "gym_outing", meeting_time: "18:00" },
      "class" => { trip_type: "class_trip", partner_company: partner_companies(:vertical_world), class_signup_url: "https://example.com/class", class_original_price: "250", weather_url: "https://example.com/weather" }
    }.transform_values do |attributes|
      Trip.create!(name: "Granite and friends", location: "Yosemite National Park", start_date: Date.new(2026, 9, 19), status: "published", participant_capacity: 8, **attributes)
    end
    public_pages = {
      "home" => root_path, "trips" => trips_path, "past-trips" => past_trips_trips_path,
      "camping" => trip_path(trips(:yosemite)), "reports" => trip_reports_path,
      "report" => trip_report_path(report), "history" => history_path, "about" => about_path,
      "membership" => membership_path, "login" => new_session_path,
      "registration" => new_registration_path, "help" => new_help_request_path
    }.merge(variants.transform_keys { |key| "trip-#{key}" }.transform_values { |trip| trip_path(trip) })
    capture_pages(public_pages)

    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"
    capture_pages({ "member-camping" => trip_path(trips(:yosemite)) }.merge(variants.transform_keys { |key| "member-#{key}" }.transform_values { |trip| trip_path(trip) }))
    capture_pages({
      "admin-trips" => admin_trips_path, "admin-trip" => admin_trip_path(trips(:yosemite)),
      "admin-trip-edit" => edit_admin_trip_path(trips(:yosemite)),
      "admin-campsite-edit" => edit_admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_a)),
      "admin-transactions" => admin_trip_transactions_path(trips(:yosemite)),
      "admin-readiness" => readiness_admin_trip_path(trips(:yosemite)),
      "admin-post-trip" => post_trip_admin_trip_path(trips(:yosemite)),
      "admin-reports" => admin_trip_reports_path, "admin-report-edit" => edit_admin_trip_report_path(report),
      "admin-users" => admin_users_path, "admin-help" => admin_help_requests_path,
      "admin-campgrounds" => admin_campgrounds_path, "profile" => profile_path,
      "profile-edit" => edit_profile_path
    })
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if ENV["UI_PARITY_OUTPUT"].present?
    travel_back
  end

  private

  def capture_pages(pages)
    directory = Pathname.new(ENV.fetch("UI_PARITY_OUTPUT"))
    FileUtils.mkdir_p(directory)
    pages.each do |name, path|
      [ 390, 760, 1440 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width <= 760)
        visit path
        assert_no_selector ".rails-default-error-page"
        # Exclude transient messages, disable motion, and load every lazy image before capture.
        page.execute_script(<<~JS)
          document.querySelectorAll('.flash-messages').forEach(n => n.remove());
          document.querySelectorAll('img').forEach(n => { n.loading = 'eager'; n.decoding = 'sync'; });
          const style = document.createElement('style');
          style.textContent = '*, *::before, *::after { animation: none !important; transition: none !important; caret-color: transparent !important; } html { scroll-behavior: auto !important; }';
          document.head.append(style);
        JS
        Selenium::WebDriver::Wait.new(timeout: 15).until do
          page.evaluate_script("document.fonts.status === 'loaded' && [...document.images].every(i => i.complete)")
        end
        page.driver.browser.execute_async_script(<<~JS)
          const done = arguments[arguments.length - 1];
          Promise.all([...document.images].map(i => i.decode().catch(() => {})))
            .then(async () => {
              // Rasterize photos at the requested viewport before the full-page capture.
              for (let y = 0; y < document.documentElement.scrollHeight; y += innerHeight) {
                scrollTo(0, y);
                await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
              }
              scrollTo(0, 0);
              requestAnimationFrame(() => requestAnimationFrame(done));
            });
        JS
        # Geometry and computed styles catch layout changes independently of pixel rendering.
        metrics = page.evaluate_script(<<~JS)
          [...document.querySelectorAll('h1,h2,h3,.panel,.button,input[type=submit],.status,.status-pill,.stats,.stats > div,.actions,.form-actions,.trip-card,.site-name')].map(n => {
            const r = n.getBoundingClientRect(), s = getComputedStyle(n);
            return {tag:n.tagName, text:n.textContent.trim().replace(/\\s+/g,' ').slice(0,120),
              rect:[r.x,r.y,r.width,r.height].map(v=>Math.round(v*100)/100),
              styles:Object.fromEntries(['display','font-size','font-weight','line-height','padding','margin','gap','color','background-color','border','border-radius','align-items','justify-content'].map(p=>[p,s.getPropertyValue(p)]))};
          })
        JS
        File.write(directory.join("#{name}-#{width}.json"), JSON.pretty_generate(metrics))
        screenshot = page.driver.browser.execute_cdp("Page.captureScreenshot", captureBeyondViewport: true,
          clip: { x: 0, y: 0, width: width, height: page.evaluate_script("document.documentElement.scrollHeight"), scale: 1 })
        File.binwrite(directory.join("#{name}-#{width}.png"), Base64.decode64(screenshot.fetch("data")))
      end
    end
    File.write(directory.join("revision.txt"), `git rev-parse HEAD`.strip + "\n")
  end
end
