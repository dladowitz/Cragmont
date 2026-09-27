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
    campgrounds(:upper_pines).update!(name: "Hodgdon Meadow Campground")
    trips(:yosemite).update!(name: "Yosemite Valley and Tuolumne Meadows Climbing Weekend")
    {
      "trips" => admin_trips_path,
      "reimbursements" => admin_campsite_reimbursements_path(filters: "1", reimbursement_status: [ "all" ]),
      "manage" => admin_trip_path(trips(:yosemite))
    }.each do |name, path|
      visit path
      [ [ 1440, 1000 ], [ 981, 900 ], [ 980, 900 ], [ 768, 1024 ], [ 760, 1024 ], [ 717, 512 ], [ 390, 844 ], [ 344, 882 ] ].each do |width, height|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width <= 760)
        assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0, "#{name} at #{width}px"
        if name == "manage"
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
          end
          first(".admin-record-table").evaluate_script("this.scrollIntoView({block: 'start', behavior: 'instant'})")
        end
        save_screenshot(Rails.root.join("tmp/screenshots/admin-mobile-#{name}-#{width}.png"))
      end
    end
    tap find(".trip-management-actions a", text: "Trip Readiness")
    assert_current_path readiness_admin_trip_path(trips(:yosemite))
  end

  test "mobile filters stay understandable and reimbursement can be completed from a record" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit admin_trips_path
    assert_selector ".trip-filter-disclosure:not([open]) > summary", text: "Draft, Published"
    find(".trip-filter-disclosure > summary").send_keys(:enter)
    find_field("Draft").send_keys(:space)
    find_field("Archived").send_keys(:space)
    assert_checked_field "Archived"
    tap find_button("Apply filters")
    assert_selector ".trip-filter-disclosure:not([open]) > summary", text: "Published, Archived"
    assert_no_selector ".admin-record-table", text: trips(:jtree).name
    find(".trip-filter-disclosure > summary").send_keys(:enter)
    assert_checked_field "Published"
    assert_checked_field "Archived"
    assert_unchecked_field "Draft"
    save_screenshot(Rails.root.join("tmp/screenshots/admin-mobile-filters.png"))

    visit admin_campsite_reimbursements_path
    assert_selector :select, "View campsites", selected: "Unreimbursed"
    save_screenshot(Rails.root.join("tmp/screenshots/admin-mobile-reimbursement-filter.png"))
    select "All campsites", from: "View campsites"
    tap find_button("Apply", exact: true)
    assert_selector "#campsite-reimbursement-#{campsites(:yosemite_b).id}"
    tap find("#campsite-reimbursement-#{campsites(:yosemite_a).id}").find_button("Record Reimbursement")
    within "dialog[open]" do
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
      select users(:sam).full_name, from: "Reimbursed by"
      select "Venmo", from: "Reimbursement method"
      fill_in "Date of reimbursement", with: "2026-09-27"
      tap find_button("Record Reimbursement")
    end
    assert_no_selector "dialog[open]"
    assert_selector :select, "View campsites", selected: "All campsites"
    assert_selector "#campsite-reimbursement-#{campsites(:yosemite_a).id} td[data-label='Reimbursed']", exact_text: "Yes"
    assert_equal users(:sam), campsites(:yosemite_a).reload.registration_reimbursed_by
    select "Reimbursed", from: "View campsites"
    tap find_button("Apply", exact: true)
    assert_selector "#campsite-reimbursement-#{campsites(:yosemite_a).id}"
    assert_no_selector "#campsite-reimbursement-#{campsites(:yosemite_b).id}"
  end

  private

  def tap(element)
    element.evaluate_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
    point = element.evaluate_script("({x: this.getBoundingClientRect().x + this.offsetWidth / 2, y: this.getBoundingClientRect().y + this.offsetHeight / 2})")
    page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [ point ])
    page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
  end
end
