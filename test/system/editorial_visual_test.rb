require "application_system_test_case"

class EditorialVisualTest < ApplicationSystemTestCase
  test "badges keep their colors and login actions use two rows on a phone" do
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
    find("input[type=email]").set("alex@example.com")
    find("input[type=password]").set("password")
    click_button "Log in"
    assert_selector ".flash.notice", text: "You are logged in."
    visit admin_root_path
    assert_selector ".admin-context", text: "Admin"
    assert_equal "rgba(0, 0, 0, 0)", find_button("Logout").native.css_value("border-bottom-color")

    click_button "Logout"
    assert_selector ".flash.notice", text: "You are logged out."
    assert_equal 0, page.evaluate_script("document.querySelector('.home-hero').getBoundingClientRect().top")
  end
end
