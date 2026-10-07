require "application_system_test_case"

class ResourcesTest < ApplicationSystemTestCase
  WIDTHS = [ [ 1440, 900 ], [ 760, 1024 ], [ 390, 844 ], [ 344, 882 ] ].freeze

  setup do
    @old_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @old_forgery_protection
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "member logs in from a category, toggles the form, formats an article, and publishes both kinds" do
    visit resource_category_path("training")
    click_link "Submit a resource"
    assert_selector ".flash.alert", text: "Tie in first: log in to submit a resource."
    fill_in "Email", with: users(:sam).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_current_path new_resource_path(category: "training")
    assert_field "Category", with: "training"
    assert_checked_field "Submit external resource"
    assert_field "Link (URL)"
    assert_no_field "Article"
    each_width("form-link") { assert_no_horizontal_overflow }

    choose "Write an article"
    assert_no_field "Link (URL)"
    assert_field "Article"
    assert_selector ".report-formatting .button", count: 4
    each_width("form-article") { assert_no_horizontal_overflow }

    choose "Submit external resource"
    fill_in "Title", with: "Hangboard protocol for new climbers"
    fill_in "Link (URL)", with: "https://example.com/hangboard"
    click_button "Publish resource"
    assert_selector ".flash.notice", text: "On belay! Your resource is up."
    assert_current_path resource_category_path("training")
    link = find("a[href='https://example.com/hangboard']")
    assert_equal "_blank", link[:target]
    assert_equal "noopener nofollow ugc", link[:rel]

    # The toast floats over the header action on desktop until dismissed.
    find(".flash-dismiss").click
    assert_no_selector ".flash"
    click_link "Submit a resource"
    choose "Write an article"
    select "News", from: "Category"
    fill_in "Title", with: "Crag cleanup recap"
    fill_in "Article", with: "Recap\nGreat turnout\nSnacks"
    { "Recap" => "Heading", "Great" => "Bold", "turnout" => "Italic", "Snacks" => "List" }.each do |text, button|
      select_article_text(text)
      click_button button, exact: true
    end
    assert_field "Article", with: "## Recap\n**Great** *turnout*\n- Snacks"
    click_button "Publish resource"
    assert_selector ".flash.notice", text: "On belay! Your resource is up."
    assert_current_path resource_category_path("news")

    click_link "Crag cleanup recap"
    assert_selector "h1", text: "Crag cleanup recap"
    assert_selector ".club-copy h2", text: "Recap"
    assert_selector ".club-copy strong", text: "Great"
    assert_selector ".club-copy em", text: "turnout"
    assert_selector ".club-copy li", text: "Snacks"
    each_width("article") { assert_no_horizontal_overflow }

    Resource.create!(user: users(:alex), category: "news", kind: "link",
      title: "A very long resource title about multi-pitch anchor building and rope management at the crag",
      url: "https://example.com/#{'long-path-segment-' * 8}")
    visit resource_category_path("news")
    each_width("category") do |width|
      assert_no_horizontal_overflow
      assert_selector ".resource-entry", count: 2
      assert_operator find_link("Submit a resource").native.rect.height, :>=, 44 if width <= 390
    end
  end

  test "Resources menu works on phones and the full super-admin navigation fits on desktop" do
    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"
    visit trip_reports_path

    [ [ 1440, 900 ], [ 1280, 900 ], [ 1100, 900 ], [ 981, 900 ] ].each do |width, height|
      emulate(width, height)
      assert_no_horizontal_overflow
      nav = find("nav.public-nav")
      summaries = all("nav.public-nav > details > summary").map(&:text)
      assert_equal [ "Trips", "Resources", "Club", "Alex Rivera" ], summaries
      all("nav.public-nav > details > summary").each do |summary|
        assert_in_delta summaries_top(nav), summary.native.rect.y, 2, "#{summary.text} wrapped at #{width}"
        assert_operator summary.native.rect.x + summary.native.rect.width, :<=, width
      end
      save_screenshot(Rails.root.join("tmp/screenshots/resources-nav-admin-#{width}.png"))
    end

    find("nav.public-nav summary", text: "Resources").click
    assert_selector ".public-nav-group[open] a", text: "Upcoming Events"
    find(".public-nav-dropdown a", text: "Upcoming Events").send_keys(:escape)
    assert_no_selector ".public-nav-group[open]"

    emulate(390, 844)
    find(".public-nav-toggle").click
    find(".public-nav-group summary", text: "Resources").click
    save_screenshot(Rails.root.join("tmp/screenshots/resources-nav-mobile-390.png"))
    find(".public-nav-dropdown a", text: "Vendors", exact_text: true).click
    assert_current_path resource_category_path("vendors")
    assert_selector "h1", text: "Vendors"
  end

  private

  def emulate(width, height)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width <= 760)
  end

  def each_width(name)
    WIDTHS.each do |width, height|
      emulate(width, height)
      yield width
      page.execute_script("window.scrollTo(0, 0)")
      save_screenshot(Rails.root.join("tmp/screenshots/resources-#{name}-#{width}.png"))
    end
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def assert_no_horizontal_overflow
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
  end

  def summaries_top(nav)
    nav.first("details > summary").native.rect.y
  end

  def select_article_text(text)
    page.execute_script(<<~JS, text)
      const field = document.getElementById("resource_body")
      const start = field.value.indexOf(arguments[0])
      field.focus()
      field.setSelectionRange(start, start + arguments[0].length)
    JS
  end
end
