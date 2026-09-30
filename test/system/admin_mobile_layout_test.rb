require "application_system_test_case"

class AdminMobileLayoutTest < ApplicationSystemTestCase
  setup do
    campsites(:yosemite_a).update!(registration_fee: "84.25")
    campsites(:yosemite_b).update!(registration_fee: "0")
    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "admin records and navigation reflow without horizontal scrolling on small screens" do
    help_request = HelpRequest.create!(user: users(:sam), reason: "trip_help", subject: "Arriving late for the Yosemite climbing weekend",
      name: "Sam Lee", email: "a-long-participant-address@example.com", message: "Where should I meet the group?")
    campgrounds(:upper_pines).update!(name: "Hodgdon Meadow Campground")
    resources = { "WhatsApp Group" => "https://chat.whatsapp.com/test", "Weather" => "https://forecast.weather.gov/test", "Mountain Project" => "https://www.mountainproject.com/area/test", "Guide Book" => "https://example.com/a-long-guide-book-address", "Google Photo Album" => "https://photos.app.goo.gl/test" }
    trips(:yosemite).update!(name: "Yosemite Valley and Tuolumne Meadows Climbing Weekend",
      whatsapp_group: resources["WhatsApp Group"], weather_url: resources["Weather"], mountain_project_url: resources["Mountain Project"],
      guide_book_url: resources["Guide Book"], photo_album_url: resources["Google Photo Album"], sun_exposure: "Afternoon shade")
    {
      "trips" => admin_trips_path,
      "reimbursements" => admin_campsite_reimbursements_path(filters: "1", reimbursement_status: [ "all" ]),
      "help" => admin_help_requests_path,
      "campgrounds" => admin_campgrounds_path,
      "assigned-campsites" => admin_campground_path(campgrounds(:upper_pines)),
      "manage" => admin_trip_path(trips(:yosemite))
    }.each do |name, path|
      visit path
      [ [ 1440, 1000 ], [ 981, 900 ], [ 980, 900 ], [ 768, 1024 ], [ 760, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{name} at #{width}px"
        if name == "manage"
          within ".admin-trip-resources-panel" do
            assert_text "Afternoon shade"
            resources.each do |label, url|
              link = find("a[href='#{url}']")
              assert_equal(width <= 760 ? label : url, link.text)
              assert_equal url, link[:href]
              assert_equal "_blank", link[:target]
              assert_equal "noopener", link[:rel]
              if width <= 760
                assert_no_text url
                assert_equal "underline", link.native.css_value("text-decoration-line")
                assert_operator link.native.rect.height, :>=, 44
              end
            end
          end
          find(".admin-trip-resources-panel").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
          save_screenshot(Rails.root.join("tmp/screenshots/admin-resources-#{width}.png"))
          links = all(".trip-management-actions > a")
          if width <= 980
            assert_equal 1, links.map { |link| link.native.rect.x }.uniq.size
            assert_equal 1, links.map { |link| link.native.rect.width }.uniq.size
            assert_in_delta find(".trip-management-content").native.rect.width, links.first.native.rect.width, 1
            links.each { |link| assert_operator link.native.rect.height, :>=, 48 }
            assert_equal "0px", links.last.native.css_value("border-bottom-width")
          end
          find(".trip-management-panel").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
        else
          all(".admin-record-table").each do |table|
            assert_equal(width <= 980 ? "grid" : "table-row", table.first("tbody > tr").native.css_value("display"))
            next if width > 980

            assert_operator table.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1
            assert_equal "none", table.evaluate_script("getComputedStyle(this, '::before').display")
            table.all(":scope > tbody > tr > td").each do |cell|
              assert_operator cell.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1, "Clipped #{cell.text} at #{width}px"
            end
            if name == "trips"
              table.all(":scope > tbody > tr > td:nth-child(n + 2):nth-child(-n + 5)").each do |cell|
                assert_equal "right", cell.native.css_value("text-align")
                assert_equal "left", cell.evaluate_script("getComputedStyle(this, '::before').textAlign")
                cell.all(":scope > .status, :scope > .date-pair").each do |value|
                  assert_in_delta cell.native.rect.x + cell.native.rect.width, value.native.rect.x + value.native.rect.width, 1
                end
              end
            end
            if name == "help"
              row = table.first("tbody > tr")
              assert_operator row.find(".table-actions").native.rect.y, :>, row.find("td[data-label='Received']").native.rect.y
            end
          end
          first(".admin-record-table").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
        end
        save_screenshot(Rails.root.join("tmp/screenshots/admin-mobile-#{name}-#{width}.png"))
      end
    end
    visit admin_trip_path(trips(:yosemite))
    find(".trip-management-actions a", text: "Trip Readiness").click
    assert_current_path readiness_admin_trip_path(trips(:yosemite))
    visit admin_help_requests_path
    find(".trip-filter-disclosure > summary").send_keys(:return)
    find_field("Replied").send_keys(:space)
    find_field("Resolved").send_keys(:space)
    find_button("Apply", exact: true).send_keys(:return)
    assert_selector ".trip-filter-disclosure:not([open]) > summary", text: "Filters: Open", exact_text: true
    click_link "View", exact: true
    assert_current_path admin_help_request_path(help_request)
    visit admin_campgrounds_path
    click_link "Hodgdon Meadow Campground", exact: true
    assert_current_path admin_campground_path(campgrounds(:upper_pines))
    find(".admin-record-table").find_link(trips(:yosemite).name, match: :first).click
    assert_current_path admin_trip_path(trips(:yosemite))
  end

  test "mobile filters stay understandable and reimbursement can be completed from a record" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
    visit admin_trips_path
    assert_selector ".trip-filter-disclosure:not([open]) > summary", text: "Draft, Published"
    find(".trip-filter-disclosure > summary").send_keys(:return)
    find_field("Draft").send_keys(:space)
    find_field("Archived").send_keys(:space)
    assert_checked_field "Archived"
    click_button "Apply filters"
    assert_selector ".trip-filter-disclosure:not([open]) > summary", text: "Published, Archived"
    assert_no_selector ".admin-record-table", text: trips(:jtree).name
    find(".trip-filter-disclosure > summary").send_keys(:return)
    assert_checked_field "Published"
    assert_checked_field "Archived"
    assert_unchecked_field "Draft"
    save_screenshot(Rails.root.join("tmp/screenshots/admin-mobile-filters.png"))

    visit admin_campsite_reimbursements_path
    assert_selector :select, "View campsites", selected: "Unreimbursed"
    select_field = find_field("View campsites")
    assert_equal "48px", select_field.native.css_value("padding-right")
    assert_equal "calc(100% - 24px) 50%, calc(100% - 17px) 50%", select_field.native.css_value("background-position")
    save_screenshot(Rails.root.join("tmp/screenshots/admin-mobile-reimbursement-filter.png"))
    select "All campsites", from: "View campsites"
    click_button "Apply", exact: true
    assert_selector "#campsite-reimbursement-#{campsites(:yosemite_b).id}"
    find("#campsite-reimbursement-#{campsites(:yosemite_a).id}").click_button("Record Reimbursement")
    within "dialog[open]" do
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
      [ 344, 390, 1440 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: false)
        all("label .required-marker", count: 3).each do |marker|
          assert_equal "inline", marker.native.css_value("display")
        end
      end
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
      select users(:sam).full_name, from: "Reimbursed by"
      select "Venmo", from: "Reimbursement method"
      fill_in "Date of reimbursement", with: "2026-09-27"
      find_field("Date of reimbursement").send_keys(:escape, :tab)
      click_button "Record Reimbursement"
    end
    assert_no_selector "dialog[open]"
    assert_selector :select, "View campsites", selected: "All campsites"
    assert_selector "#campsite-reimbursement-#{campsites(:yosemite_a).id} td[data-label='Reimbursed']", exact_text: "Yes"
    assert_equal users(:sam), campsites(:yosemite_a).reload.registration_reimbursed_by
    select "Reimbursed", from: "View campsites"
    click_button "Apply", exact: true
    assert_selector "#campsite-reimbursement-#{campsites(:yosemite_a).id}"
    assert_no_selector "#campsite-reimbursement-#{campsites(:yosemite_b).id}"
  end

  test "trip details email template preview fits a phone viewport" do
    TripDetailsEmailTemplate.ensure_defaults!
    template = TripDetailsEmailTemplate.find_by!(area_key: "yosemite", name: "Yosemite")
    visit edit_admin_trip_details_email_template_path(template)

    [ 320, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: false)
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "Page at #{width}px"
      preview = find(".trip-details-email-preview-panel")
      assert_operator preview.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1, "Preview at #{width}px"
    end
  end

  test "admin directories and user history show complete records without sideways scrolling" do
    User.create!(first_name: "Alexandria", last_name: "Very-Long-Climbing-Partner-Name",
      email: "alexandria.very-long-climbing-partner-name@example.com", password: "password")
    attach_test_waiver_to(create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam)))
    TripDetailsEmailTemplate.ensure_defaults!

    {
      "users" => admin_users_path,
      "user detail" => admin_user_path(users(:sam)),
      "partners" => admin_partner_companies_path,
      "email templates" => admin_trip_details_email_templates_path
    }.each do |name, path|
      visit path
      assert_selector ".admin-record-table tbody tr"
      [ 320, 390 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: false)
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{name} page at #{width}px"
        all(".admin-record-table").each do |table|
          assert_equal "block", table.native.css_value("display"), "#{name} table at #{width}px"
          assert_operator table.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1, "#{name} table at #{width}px"
          table.all(":scope > tbody > tr > td").each do |cell|
            assert_operator cell.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1, "#{name} cell #{cell.text} at #{width}px"
          end
        end
      end
    end
  end
end
