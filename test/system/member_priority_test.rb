require "application_system_test_case"

class MemberPriorityTest < ApplicationSystemTestCase
  test "priority notice and settings work across responsive widths" do
    trip = trips(:yosemite)
    arrival = Date.current + 30
    trip.update!(start_date: arrival, end_date: arrival + 3, first_published_at: Time.current, members_only_until: 15.days.from_now)
    trip.campsites.each { |campsite| campsite.update!(arrival_date: arrival, checkout_date: arrival + 3) }
    visit new_session_path
    fill_in "Email", with: users(:sam).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav", text: "Sam Lee"

    [ 360, 760, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width <= 760)
      visit trips_path
      assert_selector ".trip-card .status", text: /members first/i
      assert_no_overflow
      visit trip_path(trip)
      assert_selector ".member-priority-notice", text: "Non-member signup and waitlist access open"
      assert_no_button "Sign up for this campsite"
      assert_no_button "Join waitlist"
      assert_no_overflow
      save_screenshot(Rails.root.join("tmp/screenshots/member-priority-#{width}.png"))
    end
    find(".member-priority-notice a", text: "About membership").send_keys(:enter)
    assert_current_path membership_path

    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav", text: "Alex Rivera"
    [ 360, 760, 1440 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width <= 760)
      visit admin_settings_path
      assert_field "Member-only signup period (days)", with: "15"
      assert_no_overflow
      save_screenshot(Rails.root.join("tmp/screenshots/member-priority-settings-#{width}.png"))
    end
    fill_in "Member-only signup period (days)", with: "21"
    click_button "Save settings"
    assert_selector ".flash.notice", text: "Settings were updated."
    assert_field "Member-only signup period (days)", with: "21"
    assert_equal 21, SiteSetting.current.camping_member_priority_days
    visit trip_path(trip)
    assert_button "Sign up for this campsite", minimum: 1
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def assert_no_overflow
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("innerWidth")
  end
end
