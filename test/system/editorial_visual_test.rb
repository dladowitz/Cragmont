require "application_system_test_case"

class EditorialVisualTest < ApplicationSystemTestCase
  test "long history reads without horizontal scrolling on a phone" do
    visit history_path
    assert_selector "#longer-history h2", text: "From Cragmont Rock to Yosemite"

    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert_equal 390, page.evaluate_script("window.innerWidth")
    assert_operator find("#longer-history").native.rect.width, :<=, 390
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - window.innerWidth"), :<=, 0
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "calendar subscription has room to breathe on desktop and phone" do
    visit trips_path
    notice = find(".calendar-subscription-notice")
    assert_equal 2, notice.all("p").size
    assert_operator notice.native.rect.height, :>, 70

    page.driver.browser.manage.window.resize_to(390, 844)
    assert_operator notice.native.rect.height, :>, 90
  end

  test "badges, login actions, and the signed in menu work on a phone" do
    visit new_session_path

    colors = page.evaluate_script(<<~JS)
      (() => {
        return ["status", "status warning-status", "status danger-status",
          "status-pill open-status", "status-pill resolved-status",
          "status trip-type-badge external-class-badge", "status trip-type-badge day-trip-badge"].map(classes => {
          const badge = document.createElement("span");
          badge.className = classes;
          document.body.append(badge);
          const color = getComputedStyle(badge).backgroundColor;
          badge.remove();
          return color;
        });
      })()
    JS

    assert_equal 6, colors.uniq.size
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
    find(".public-nav-toggle").click
    find(".account-nav summary").click
    assert_selector ".account-nav[open] a[href='#{profile_path}']", text: "Profile"
    assert_button "Log out"

    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit admin_root_path
    assert_selector ".admin-context", text: "Admin"
    logout = find_button("Logout")
    assert_equal "rgba(0, 0, 0, 0)", logout.native.css_value("border-bottom-color")

    page.execute_script("arguments[0].form.requestSubmit(arguments[0])", logout.native)
    assert_selector ".flash.notice", text: "You are logged out."
    assert_equal 0, page.evaluate_script("document.querySelector('.home-hero').getBoundingClientRect().top")
  end
end
