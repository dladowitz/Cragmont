require "application_system_test_case"

class EditorialVisualTest < ApplicationSystemTestCase
  setup { LegacyTripReportImport.call }

  test "report galleries keep photos compact and provide a thumbnail when empty" do
    report = TripReport.find_by!(legacy_key: "2026-08-22-snowshed-tahoe")
    uploads = %w[2026-08-14-tuolumne.jpg 2026-08-22-snowshed-tahoe.jpg].map do |name|
      Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/trip-reports", name), "image/jpeg")
    end
    report.add_photos!(uploads, version: report.lock_version, actor: users(:alex))
    report.publish!(version: report.lock_version, actor: users(:alex))
    empty = TripReport.find_by!(legacy_key: "2026-09-18-yosemite-valley")
    empty.update!(published: empty.published.except("legacy_image"))

    [ trip_reports_path, trip_report_path(report) ].each do |path|
      visit path
      [ 1440, 390, 344 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width <= 760)
        photos = all("#report-#{report.id} .club-report-gallery img", count: path == trip_reports_path ? 1 : 3)
        photos.each do |photo|
          assert_operator photo.native.rect.height, :<=, 280
          assert_in_delta photos.first.native.rect.width, photo.native.rect.width, 1
          assert_in_delta photos.first.native.rect.height, photo.native.rect.height, 1
        end
        if path == trip_reports_path
          assert_selector "#report-#{empty.id} .club-report-gallery-placeholder img[alt*='sample']"
          assert_in_delta photos.first.native.rect.height, find("#report-#{empty.id} .club-report-gallery img").native.rect.height, 1
          assert_link "View photos", href: empty.published["album_url"]
          find("#report-#{empty.id}").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
          save_screenshot(Rails.root.join("tmp/screenshots/report-fallback-#{width}.png"))
        end
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        find("#report-#{report.id}").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
        save_screenshot(Rails.root.join("tmp/screenshots/report-gallery-#{path == trip_reports_path ? 'list' : 'detail'}-#{width}.png"))
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "mobile trip lists keep metadata labels left and values right" do
    trips(:jtree).update!(status: "archived")
    [ trips_path, past_trips_trips_path ].each do |path|
      visit path
      [ [ 1440, 1000 ], [ 760, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width <= 760)
        rows = all(".trip-card-meta > div, .archived-trip-meta > div", minimum: 1)
        rows.each do |row|
          value = row.find("dd")
          label = row.find("dt")
          if label.text == "Open Spaces"
            assert_equal 1, label.evaluate_script("(() => { const range = document.createRange(); range.selectNodeContents(this); return range.getClientRects().length; })()")
          end
          if width <= 760
            assert_equal "right", value.native.css_value("text-align")
            assert_in_delta row.native.rect.x, row.find("dt").native.rect.x, 1
            assert_in_delta row.native.rect.x + row.native.rect.width, value.native.rect.x + value.native.rect.width, 1
            assert_operator value.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1
          else
            assert_not_equal "right", value.native.css_value("text-align")
          end
        end
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        rows.first.evaluate_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
        save_screenshot(Rails.root.join("tmp/screenshots/trip-list-spacing-#{path == trips_path ? 'current' : 'past'}-#{width}.png"))
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "empty trip lists use inset rounded cards on mobile" do
    Trip.update_all(status: "draft")
    [ trips_path, past_trips_path ].each do |path|
      visit path
      [ 344, 390, 760 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: true)
        card = find(".trip-list-empty")
        warning = find(".public-liability-warning")
        assert_equal warning.native.css_value("background-color"), card.native.css_value("background-color")
        assert_equal warning.native.css_value("border-radius"), card.native.css_value("border-radius")
        assert_operator card.native.css_value("border-radius").to_f, :>, 0
        assert_in_delta warning.native.rect.x, card.native.rect.x, 1
        assert_in_delta warning.native.rect.width, card.native.rect.width, 1
        assert_operator card.native.rect.x, :>, 0
        assert_equal "rgba(0, 0, 0, 0)", find(".public-main > .panel").native.css_value("background-color")
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        save_screenshot(Rails.root.join("tmp/screenshots/empty-#{path == trips_path ? 'trips' : 'past-trips'}-#{width}.png"))
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "mobile trip section paragraphs and empty states share typography and heading spacing" do
    {
      "day_trip" => { meeting_time: "08:30", meeting_location: "Parking lot", meeting_location_url: "https://maps.google.com/?q=Castle+Rock", late_arrival_instructions: "Meet at the main wall.", climbing_types: [ "sport" ] },
      "gym_outing" => { meeting_time: "18:00" },
      "class_trip" => { partner_company: partner_companies(:vertical_world), class_signup_url: "https://example.com/class", class_original_price: "250", weather_url: "https://example.com/weather" }
    }.each do |type, attributes|
      trip = Trip.create!(name: "Rescue Systems Refresher", location: "Castle Rock", start_date: Date.new(2026, 9, 19),
        status: "archived", trip_type: type, participant_capacity: 8,
        description: "An outing with the club.\n\nBring your climbing gear.", **attributes)
      visit trip_path(trip)
      [ [ 1440, 1000 ], [ 760, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width <= 760)
        if width > 760
          assert_equal "rgba(88, 107, 101, 1)", find(".day-trip-participants-panel > p").native.css_value("color")
          assert_equal "rgba(255, 254, 250, 1)", find(".day-trip-participants-panel").native.css_value("background-color")
          assert_equal "400", find(".day-trip-participants-panel h2").native.css_value("font-weight")
          next
        end

        assert_equal "rgba(247, 245, 239, 1)", find("body").native.css_value("background-color")
        assert_equal "700", find(".trip-show-mobile-hero h1").native.css_value("font-weight")
        if width == 390
          find(".trip-show-mobile-hero").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
          save_screenshot(Rails.root.join("tmp/screenshots/trip-hero-#{type}-#{width}.png"))
        end
        all(".public-main > .panel").each do |section|
          assert_equal "rgba(0, 0, 0, 0)", section.native.css_value("background-color")
          assert_equal "24px", section.native.css_value("margin-bottom")
        end
        all(".public-main h2").each { |heading| assert_equal "700", heading.native.css_value("font-weight") }
        assert_in_delta 10, find(".trip-overview").evaluate_script("this.getBoundingClientRect().bottom - this.querySelector('.stats').getBoundingClientRect().bottom"), 0.5
        sections = all(".day-trip-description-panel, .day-trip-participants-panel, .day-trip-coordinator-panel, .day-trip-safety-panel")
        assert_equal(type == "class_trip" ? 3 : 4, sections.size)
        sections.each do |section|
          assert_equal [ "0px", "0px" ], %w[padding-top padding-bottom].map { |property| section.native.css_value(property) }
          assert_in_delta 24, section.evaluate_script("this.getBoundingClientRect().top - this.previousElementSibling.getBoundingClientRect().bottom"), 0.5
          heading = section.first("h2")
          paragraphs = section.all(":scope > p, .content-page-markdown p")
          assert paragraphs.any?
          paragraphs.each do |paragraph|
            assert_equal [ "16px", "400", "24px", "rgba(32, 51, 48, 1)" ],
              %w[font-size font-weight line-height color].map { |property| paragraph.native.css_value(property) }, "#{type} at #{width}px"
          end
          assert_in_delta 8, paragraphs.first.native.rect.y - heading.native.rect.y - heading.native.rect.height, 1, "#{type} #{heading.text} at #{width}px"
          assert_equal "0px", paragraphs.last.native.css_value("margin-bottom")
        end
        assert_equal "14px", find(".day-trip-description-panel .content-page-markdown p:first-child").native.css_value("margin-bottom")
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        sections.first.evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
        save_screenshot(Rails.root.join("tmp/screenshots/trip-paragraphs-#{type}-#{width}.png"))
      end

      next unless type == "day_trip"

      8.times do |index|
        user = User.create!(first_name: "Climber #{index}", last_name: "Example", password: "password")
        trip.day_trip_signups.create!(user: user, climbing_abilities: [ "lead", "top_rope" ],
          rope_60m: true, rope_70m: true, quickdraws_and_sport_anchor: true, cams_nuts_and_trad_anchor: true)
      end
      visit trip_path(trip)
      [ [ 390, 844 ], [ 717, 512 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: true)
        assert_selector ".day-trip-participants-panel tbody tr", count: 8
        all(".day-trip-participants-panel tbody tr").each { |row| assert_equal "rgba(0, 0, 0, 0)", row.native.css_value("background-color") }
        coordinator = find(".day-trip-coordinator-panel")
        assert_in_delta 24, coordinator.evaluate_script("this.getBoundingClientRect().top - this.previousElementSibling.getBoundingClientRect().bottom"), 0.5
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        coordinator.evaluate_script("this.scrollIntoView({block: 'end', behavior: 'instant'})")
        save_screenshot(Rails.root.join("tmp/screenshots/trip-long-participants-#{width}.png"))
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "trip and campsite counts use distinct outlined boxes at every screen size" do
    campsites(:yosemite_a).update!(participant_capacity: 2)
    campsites(:yosemite_b).update!(participant_capacity: 2)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    [ 16, 8 ].each do |age|
      signup.campsite_signup_minors.create!(first_name: "Child", last_name: "Lee", age: age, relationship: "Child")
    end
    create_campsite_signup!(campsite: campsites(:yosemite_b), user: users(:alex))
    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"

    [ trip_path(trips(:yosemite)), admin_trip_path(trips(:yosemite)) ].each do |path|
      visit path
      [ [ 1440, 1000 ], [ 980, 900 ], [ 768, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width <= 760)
        if width <= 760 && !path.start_with?("/admin")
          assert_equal "700", find(".trip-show-mobile-hero h1").native.css_value("font-weight")
          all(".public-main > .panel").each { |section| assert_equal "rgba(0, 0, 0, 0)", section.native.css_value("background-color") }
          assert_in_delta 10, find(".trip-overview").evaluate_script("this.getBoundingClientRect().bottom - this.querySelector('.stats').getBoundingClientRect().bottom"), 0.5
          all(".campsite-card, .climbing-partner-panel, .trip-coordinator-panel", minimum: 3).each do |card|
            %w[top right bottom].each { |side| assert_equal "1px", card.native.css_value("border-#{side}-width") }
            assert_equal "4px", card.native.css_value("border-left-width")
          end
          find(".climbing-partner-panel").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
          save_screenshot(Rails.root.join("tmp/screenshots/mobile-card-borders-#{width}.png"))
        end
        all(".stats").each do |group|
          assert_equal "0px", group.native.css_value("border-top-width")
          assert_equal "0px", group.native.css_value("border-bottom-width")
        end
        all(".stats > div").each do |box|
          assert_equal "1px", box.native.css_value("border-width")
          assert_equal "5px", box.native.css_value("border-radius")
        end
        all(".parking-breakdown, .parking-breakdown-item").each do |parking|
          assert_operator parking.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1
        end
        { "success" => "rgba(236, 248, 242, 1)", "warning" => "rgba(255, 248, 219, 1)", "danger" => "rgba(255, 241, 240, 1)" }.each do |status, color|
          assert_equal color, find(".stats .#{status}-stat").native.css_value("background-color")
        end
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        first(".stats").evaluate_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
        save_screenshot(Rails.root.join("tmp/screenshots/stat-boxes-#{path.start_with?('/admin') ? 'admin' : 'public'}-#{width}.png"))
        first(".campsite-stats").evaluate_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
        save_screenshot(Rails.root.join("tmp/screenshots/campsite-stat-boxes-#{path.start_with?('/admin') ? 'admin' : 'public'}-#{width}.png"))
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "club pages and standalone reports keep the Yosemite background and readable navigation" do
    report = TripReport.where.not(legacy_key: nil).first!
    [ about_path, history_path, membership_path, join_the_list_path, trip_reports_path, trip_report_path(report) ].each do |path|
      visit path
      [ [ 1440, 900 ], [ 760, 1024 ], [ 717, 512 ], [ 360, 844 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width <= 760)
        assert_includes find("body").native.css_value("background-image"), "tuolumne-meadows-fairview-dome"
        assert_equal "fixed", find("body").native.css_value("background-attachment").split(", ").last
        assert_equal "rgba(255, 255, 255, 1)", find(".site-name").native.css_value("color")
        assert_logo_lines_separated
        assert_equal "rgba(255, 254, 250, 1)", first(".panel").native.css_value("background-color")
        assert_selector ".background-image-caption", text: "Fairview Dome, Tuolumne Meadows, Yosemite"
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        save_screenshot(Rails.root.join("tmp/screenshots/club-background-#{width}.png")) if path == about_path
      end
    end
    find(".public-nav-checkbox", visible: :all).send_keys(:space)
    summary = find(".public-nav-group summary", text: "Trips")
    assert_equal "rgba(32, 51, 48, 1)", summary.native.css_value("color")
    summary.send_keys(:enter)
    link = find(".public-nav-dropdown a", text: "Past Trips", exact_text: true)
    assert_equal "rgba(32, 51, 48, 1)", link.native.css_value("color")
    link.send_keys(:escape)
    assert_no_selector ".public-nav-group[open]"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "admin header and report actions stay aligned across screen sizes" do
    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"
    visit admin_trip_reports_path

    [ 1440, 1280, 1176, 1024, 981, 980, 840, 768, 717, 390, 344 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width <= 760)
      brand = find(".admin-brand .site-name").native.rect
      assert_logo_lines_separated
      admin = find_link("Public View", exact: true).native.rect
      assert_in_delta brand.y + brand.height / 2.0, admin.y + admin.height / 2.0, 1, "Brand alignment at #{width}px"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
      if width > 980
        nav = all(".admin-nav a, .admin-nav button")
        assert_equal 1, nav.map { |link| link.native.rect.y }.uniq.size, "Navigation wraps at #{width}px"
      else
        menu = find(".admin-nav-toggle").native.rect
        assert_in_delta brand.y + brand.height / 2.0, menu.y + menu.height / 2.0, 1, "Menu alignment at #{width}px"
        assert_no_selector ".admin-nav"
        find(".admin-nav-checkbox", visible: :all).send_keys(:space)
        assert_link "Settings"
        assert_button "Logout"
        find(".admin-nav-checkbox", visible: :all).send_keys(:escape)
        assert_no_selector ".admin-nav"
      end
      if width > 900
        actions = all(".report-management-row > .actions")
        assert_equal 1, actions.map { |row| row.native.rect.x }.uniq.size, "Report actions shift at #{width}px"
        actions.each do |row|
          assert_equal 1, row.all("a").size
        end
      end
      save_screenshot(Rails.root.join("tmp/screenshots/admin-reports-#{width}.png")) if [ 1176, 390 ].include?(width)
    end
    visit admin_trips_path
    [ 1440, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width <= 760)
      buttons = all(".admin-trips-table a.button", text: "Transactions", minimum: 1)
      buttons.each do |button|
        assert_in_delta(width > 980 ? 36 : 44, button.native.rect.height, 1)
        assert_includes %w[flex inline-flex], button.native.css_value("display")
        assert_equal "center", button.native.css_value("align-items")
      end
      buttons.first.evaluate_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
      save_screenshot(Rails.root.join("tmp/screenshots/transactions-buttons-#{width}.png"))
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "Admin and Public View are clear navigation links across screen sizes" do
    assign_role(users(:sam), :trip_admin)
    visit new_session_path
    fill_in "Email", with: users(:sam).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"

    [ root_path, about_path, admin_trip_reports_path ].each do |path|
      visit path
      [ [ 1440, 900 ], [ 768, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width <= 760)
        admin_page = path == admin_trip_reports_path
        admin = find_link(admin_page ? "Public View" : "Admin", exact: true)
        assert_equal(admin_page ? root_path : admin_root_path, URI.parse(admin[:href]).path)
        assert_equal "rgba(0, 0, 0, 0)", admin.native.css_value("background-color")
        assert_operator admin.native.rect.height, :>=, 44
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
      end
    end
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    find_link("Public View", exact: true).send_keys(:return)
    assert_current_path root_path
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "auth forms keep compact headings and deliberate action rows across screen sizes" do
    token = users(:alex).generate_password_reset_token!
    [ new_session_path, new_password_reset_path, edit_password_reset_path(token), new_registration_path ].each do |path|
      visit path
      [ [ 1440, 900 ], [ 768, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
        page.driver.browser.manage.window.resize_to(width, height)
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
        assert_selector "h1", count: 1
        assert_selector "h1", text: "Log in to Cragmont" if path == new_session_path
        assert_selector "h1", text: "Create your Cragmont account" if path == new_registration_path
        if width > 900 || path == edit_password_reset_path(token)
          heading = find("main h1")
          assert_equal "32px", heading.native.css_value("font-size")
          assert_equal "0px", heading.native.css_value("margin-top")
        end
        next unless path == new_session_path

        actions = all(".auth-panel .form-actions > *")
        assert_equal actions[0].native.rect.y, actions[1].native.rect.y
        if width > 600
          assert_equal actions[0].native.rect.y, actions[2].native.rect.y
        else
          assert_operator actions[2].native.rect.y, :>, actions[0].native.rect.y
        end
        actions.each { |action| assert_operator action.native.rect.height, :>=, 44 }
        if width > 900
          assert_operator find(".auth-panel").native.rect.height, :<, 400
        end
        if width == 717
          assert_operator actions[0].native.rect.y + actions[0].native.rect.height, :<=, height - 48
        end
      end
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "trip headings place desktop badges beside the name and retain mobile stacking" do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit trip_path(trips(:yosemite))
    assert_in_delta 58.29, find(".trip-summary-copy h1").native.css_value("font-size").to_f, 0.1
    assert_equal "32px", find(".trip-summary-copy > h2").native.css_value("font-size")
    heading = find("h1").native.rect
    assert_operator find(".trip-type-badge").native.rect.x, :>=, heading.x + heading.width
    all(".trip-summary-copy .trip-title-line > .status").each do |badge|
      rect = badge.native.rect
      assert_in_delta heading.y + heading.height / 2.0, rect.y + rect.height / 2.0, 1
    end
    save_screenshot(Rails.root.join("tmp/screenshots/trip-title-badges-desktop.png"))

    page.driver.browser.manage.window.resize_to(390, 844)
    assert_equal "28px", find(".trip-show-mobile-hero h1").native.css_value("font-size")
    assert_equal "15.36px", find(".trip-show-mobile-location").native.css_value("font-size")
    heading = find("h1").native.rect
    assert_operator find(".trip-type-badge").native.rect.y, :>=, heading.y + heading.height
    [ 1440, 760, 360 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width <= 760)
      assert_no_selector "a.trip-calendar-download"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "expanded reports animate across the grid and restore their neighbors when collapsed" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"
    visit trip_reports_path
    titles = all(".club-report h2").map(&:text)
    [ 1400, 760, 360 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width <= 760)
      report = find(".club-report", text: titles[3])
      edit = report.find_link("Edit report").native.rect
      assert_operator edit.y + edit.height, :<=, report.find("summary").native.rect.y
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
    end
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.execute_script(<<~JS)
      window.reportAnimations = 0;
      const animateReport = Element.prototype.animate;
      Element.prototype.animate = function(...args) {
        window.reportAnimations += 1;
        return animateReport.apply(this, args);
      };
    JS

    [ 2, 3 ].each do |index|
      report = find(".club-report", text: titles[index])
      neighbor = find(".club-report", text: titles[index == 2 ? 3 : 2])
      report.find("summary").send_keys(:enter)
      assert_selector ".club-report-details[open]"
      assert_equal page.evaluate_script("document.querySelector('.club-report-grid').offsetWidth"),
        page.evaluate_script("arguments[0].offsetWidth", report)
      assert_operator page.evaluate_script("arguments[0].offsetTop", neighbor), :>=,
        page.evaluate_script("arguments[0].offsetTop + arguments[0].offsetHeight", report)
      assert_equal "Read trip report", page.evaluate_script("document.activeElement.textContent")
      report.find("summary").send_keys(:space)
      assert_no_selector ".club-report-details[open]"
      assert_equal titles, all(".club-report h2").map(&:text)
    end
    assert_operator page.evaluate_script("window.reportAnimations"), :>, 0

    browser = page.driver.browser
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    animation_count = page.evaluate_script("window.reportAnimations")
    browser.manage.window.resize_to(390, 844)
    report = find(".club-report", text: titles[3])
    report.find("summary").send_keys(:enter)
    assert_selector ".club-report-details[open]"
    assert_equal titles, all(".club-report h2").map(&:text)
    assert_equal animation_count, page.evaluate_script("window.reportAnimations")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
  ensure
    browser&.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "navigation dismisses on outside clicks and Escape without breaking links" do
    visit trip_reports_path
    find(".public-nav-group summary", text: "Trips").click
    assert_selector ".public-nav-group[open]"
    find("h1").click
    assert_no_selector ".public-nav-group[open]"

    find(".public-nav-group summary", text: "Trips").click
    find(".public-nav-dropdown a", text: "Past Trips", exact_text: true).send_keys(:escape)
    assert_no_selector ".public-nav-group[open]"
    assert_equal "Trips", page.evaluate_script("document.activeElement.textContent")

    find(".public-nav-group summary", text: "Club").click
    find(".public-nav-dropdown a", text: "About", exact_text: true).click
    assert_current_path about_path

    page.driver.browser.manage.window.resize_to(390, 844)
    find(".public-nav-toggle").click
    find(".public-nav-group summary", text: "Club").click
    find(".public-nav-dropdown a", text: "About", exact_text: true).send_keys(:escape)
    assert_no_selector ".public-nav-group[open]"
    assert_selector "#public-nav-toggle:checked", visible: :all
    find(".public-nav-group summary", text: "Club").send_keys(:escape)
    assert_no_selector "#public-nav-toggle:checked", visible: :all
    assert_equal "public-nav-toggle", page.evaluate_script("document.activeElement.id")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "open navigation heading uses the Cragmont green on desktop and phone" do
    browser = page.driver.browser
    browser.manage.window.resize_to(1400, 1000)
    visit root_path
    accent = page.evaluate_script(<<~JS)
      (() => {
        const sample = document.createElement("span");
        sample.style.backgroundColor = "var(--accent)";
        document.body.append(sample);
        const color = getComputedStyle(sample).backgroundColor;
        sample.remove();
        return color;
      })()
    JS

    find(".public-nav-group summary", text: "Club").click
    assert_equal accent, page.evaluate_script("getComputedStyle(document.querySelector('.public-nav-group[open] > summary')).backgroundColor")

    browser.manage.window.resize_to(390, 844)
    find(".public-nav-toggle").click
    find(".public-nav-group summary", text: "Trips").click
    assert_equal accent, page.evaluate_script("getComputedStyle(document.querySelector('.public-nav-group[open] > summary')).backgroundColor")
  ensure
    browser&.manage&.window&.resize_to(1400, 1000)
  end

  test "long history reads without horizontal scrolling on a phone" do
    visit history_path
    assert_selector ".club-copy h2", text: "The Early History of the Cragmont Climbing Club from Camp 4"

    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert_equal 390, page.evaluate_script("window.innerWidth")
    assert_operator find(".club-copy").native.rect.width, :<=, 390
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - window.innerWidth"), :<=, 0
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "calendar subscription stays concise and readable on desktop and phone" do
    visit trips_path
    notice = find(".calendar-subscription-notice")
    assert_equal 1, notice.all("p").size
    assert_link "Subscribe to all events"
    assert_no_text "Keep your next climb on the calendar"

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert_operator notice.native.rect.width, :<=, 390
    assert_link "iCal feed URL"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "badges, login actions, and the signed in menu work on a phone" do
    visit new_session_path

    colors = page.evaluate_script(<<~JS)
      (() => {
        return ["status", "status warning-status", "status danger-status",
          "status-pill open-status", "status-pill resolved-status",
          "status trip-type-badge external-class-badge", "status trip-type-badge day-trip-badge",
          "status trip-type-badge gym-outing-badge"].map(classes => {
          const badge = document.createElement("span");
          badge.className = classes;
          document.body.append(badge);
          const color = getComputedStyle(badge).backgroundColor;
          badge.remove();
          return color;
        });
      })()
    JS

    assert_equal 7, colors.uniq.size
    assert_not_includes colors, "rgba(0, 0, 0, 0)"

    page.driver.browser.manage.window.resize_to(390, 844)
    actions = all(".auth-panel .form-actions > *")
    assert_equal actions[0].native.rect.y, actions[1].native.rect.y
    assert_operator actions[2].native.rect.y, :>, actions[0].native.rect.y

    page.driver.browser.manage.window.resize_to(1400, 1000)
    page.execute_script("arguments[0].value = arguments[1]", find_field("Email"), "alex@example.com")
    page.execute_script("arguments[0].value = arguments[1]", find_field("Password"), "password")
    login = find_button("Log in")
    page.execute_script("arguments[0].form.requestSubmit(arguments[0])", login)
    assert_selector ".flash.notice", text: "You are logged in."

    page.driver.browser.manage.window.resize_to(390, 844)
    assert_operator find(".flash-messages").native.rect.y, :>=, find(".public-header").native.rect.height
    page.execute_script("document.querySelector('#public-nav-toggle').checked = true; document.querySelector('.account-nav').open = true")
    assert_selector ".account-nav[open] a[href='#{profile_path}']", text: "Profile"
    assert_button "Log out"

    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit admin_root_path
    assert_selector ".admin-mode-label", text: "Admin Dashboard"
    logout = find_button("Logout")
    assert_equal "rgba(0, 0, 0, 0)", logout.native.css_value("border-bottom-color")

    page.execute_script("arguments[0].form.requestSubmit(arguments[0])", logout.native)
    assert_selector ".flash.notice", text: "You are logged out."
    assert_equal 0, page.evaluate_script("document.querySelector('.home-hero').getBoundingClientRect().top")
    assert_operator find(".flash-messages").native.rect.y, :>=, find(".public-header").native.rect.height
    assert_equal page.evaluate_script("getComputedStyle(document.body).color"), page.evaluate_script("getComputedStyle(document.querySelector('.flash-text')).color")
    assert_no_selector ".flash.notice", visible: true, wait: 3
  end

  private

  def assert_logo_lines_separated
    top = find(".site-name span")
    bottom = find(".site-name small")
    [ top, bottom ].each do |line|
      assert_operator line.native.css_value("line-height").to_f, :>=, line.native.css_value("font-size").to_f
    end
    assert_operator bottom.native.rect.y - (top.native.rect.y + top.native.rect.height), :>=, 1
  end
end
