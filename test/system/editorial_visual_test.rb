require "application_system_test_case"

class EditorialVisualTest < ApplicationSystemTestCase
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

  test "trip headings are slightly smaller on desktop and unchanged on mobile" do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit trip_path(trips(:yosemite))
    assert_in_delta 58.29, find(".trip-summary-copy h1").native.css_value("font-size").to_f, 0.1
    assert_equal "32px", find(".trip-summary-copy > h2").native.css_value("font-size")

    page.driver.browser.manage.window.resize_to(390, 844)
    assert_equal "28px", find(".trip-show-mobile-hero h1").native.css_value("font-size")
    assert_equal "15.36px", find(".trip-show-mobile-location").native.css_value("font-size")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "expanded reports animate across the grid and restore their neighbors when collapsed" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit trip_reports_path
    titles = all(".club-report h2").map(&:text)
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
  ensure
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
    assert_selector ".admin-context", text: "Admin"
    logout = find_button("Logout")
    assert_equal "rgba(0, 0, 0, 0)", logout.native.css_value("border-bottom-color")

    page.execute_script("arguments[0].form.requestSubmit(arguments[0])", logout.native)
    assert_selector ".flash.notice", text: "You are logged out."
    assert_equal 0, page.evaluate_script("document.querySelector('.home-hero').getBoundingClientRect().top")
    assert_operator find(".flash-messages").native.rect.y, :>=, find(".public-header").native.rect.height
    assert_equal page.evaluate_script("getComputedStyle(document.body).color"), page.evaluate_script("getComputedStyle(document.querySelector('.flash-text')).color")
    assert_no_selector ".flash.notice", visible: true, wait: 3
  end
end
