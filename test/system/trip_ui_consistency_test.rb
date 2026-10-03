require "application_system_test_case"

class TripUiConsistencyTest < ApplicationSystemTestCase
  test "trip lists share card styling and every trip type keeps the same badge across pages" do
    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"

    types = {
      "camping" => {},
      "day_trip" => { meeting_time: "08:30", meeting_location: "Parking lot", meeting_location_url: "https://maps.google.com/?q=Castle+Rock", late_arrival_instructions: "Meet at the main wall.", climbing_types: [ "sport" ] },
      "gym_outing" => { meeting_time: "18:00" },
      "class_trip" => { partner_company: partner_companies(:vertical_world), class_signup_url: "https://example.com/class", class_original_price: "250", weather_url: "https://example.com/weather" }
    }
    types.each do |type, attributes|
      trip = Trip.create!(name: "Shared #{type.humanize} card", location: "Yosemite National Park", start_date: Date.new(2026, 9, 19),
        end_date: Date.new(2026, 9, 19), status: "published", trip_type: type, participant_capacity: 8, **attributes)
      payload = TripReport.trip_payload(trip).merge("body" => "A day on the rock.")
      report = TripReport.create!(draft: payload, published: payload, published_at: Time.current)
      [ 1440, 760, 390, 320 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width <= 760)
        trip.update!(status: "published")
        visit trips_path
        card = find(".trip-card[href='#{trip_path(trip)}']")
        reference = card_styles(card)
        badge = badge_styles(card.find(".trip-type-badge"))
        assert_equal "11.52px", badge.fetch("font-size")
        assert_equal "3px 7px", badge.fetch("padding")
        assert_fits_viewport
        save_screenshot(Rails.root.join("tmp/screenshots/shared-trips-#{width}.png")) if type == "camping"

        [ trip_path(trip), trip_report_path(report), admin_trips_path ].each do |path|
          visit path
          selector = path == admin_trips_path ? ".admin-trips-table tr:has(a[href='#{admin_trip_path(trip)}']) .trip-type-badge" : ".trip-type-badge"
          assert_equal badge, badge_styles(find(selector)), "#{type} badge at #{path}, #{width}px"
          assert_fits_viewport
        end

        trip.update!(status: "archived")
        visit past_trips_trips_path
        archived = find(".trip-card[href='#{trip_path(trip)}']")
        assert_equal reference, card_styles(archived), "Past Trips card differs at #{width}px"
        assert_equal badge, badge_styles(archived.find(".trip-type-badge"))
        assert_text(trip.single_day_event? ? "Participants" : "Sites")
        assert_fits_viewport
        save_screenshot(Rails.root.join("tmp/screenshots/shared-past-trips-#{width}.png")) if type == "camping"
      end
      trip.destroy!
      report.destroy!
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def computed_styles(node, properties)
    node.evaluate_script("Object.fromEntries(#{properties.to_json}.map(p => [p, getComputedStyle(this).getPropertyValue(p)]))")
  end

  def badge_styles(node)
    computed_styles(node, %w[font-size font-weight line-height letter-spacing padding border-radius background-color color align-items])
  end

  def card_styles(card)
    selectors = { "card" => card, "title" => card.find("h2"), "subtitle" => card.find(".trip-card-title-line"), "metadata" => card.find("dl"), "dates" => card.find("dl > div", match: :first) }
    selectors.transform_values { |node| computed_styles(node, %w[font-size font-weight line-height padding margin gap grid-template-columns background-color border border-radius]) }
  end

  def assert_fits_viewport
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - innerWidth"), :<=, 0
  end
end
