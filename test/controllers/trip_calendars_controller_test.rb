require "test_helper"

class TripCalendarsControllerTest < ActionDispatch::IntegrationTest
  test "anonymous subscription contains published and archived events but no drafts or deleted trips" do
    archived = Trip.create!(name: "Past crag day", location: "California", start_date: "2026-01-01", end_date: "2026-01-01", status: "archived")
    deleted = Trip.create!(name: "Removed trip", location: "California", start_date: "2026-09-10", end_date: "2026-09-10", status: "published", deleted_at: Time.current)

    get calendar_trips_url(format: :ics)

    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_includes response.headers["Content-Disposition"], "cragmont-events.ics"
    assert_includes response.body, "UID:trip-#{trips(:yosemite).id}@cragmontclimbing.com"
    assert_includes response.body, "UID:trip-#{archived.id}@cragmontclimbing.com"
    refute_includes response.body, "UID:trip-#{trips(:jtree).id}@cragmontclimbing.com"
    refute_includes response.body, "UID:trip-#{deleted.id}@cragmontclimbing.com"
    refute_includes response.body, "DESCRIPTION:"
  end

  test "single event download shares subscription UID and observes visibility" do
    trip = trips(:yosemite)
    get calendar_trip_url(trip, format: :ics)
    assert_response :success
    assert_equal 1, response.body.scan("BEGIN:VEVENT").count
    assert_includes response.body, "UID:trip-#{trip.id}@cragmontclimbing.com"

    trip.update!(status: "archived")
    get calendar_trip_url(trip, format: :ics)
    assert_response :success

    get calendar_trip_url(trips(:jtree), format: :ics)
    assert_response :not_found

    trip.soft_delete!
    get calendar_trip_url(trip, format: :ics)
    assert_response :not_found
  end

  test "an empty feed is a valid empty calendar" do
    Trip.update_all(status: "draft")
    get calendar_trips_url(format: :ics)
    assert_response :success
    assert response.body.start_with?("BEGIN:VCALENDAR\r\n")
    assert response.body.end_with?("END:VCALENDAR\r\n")
    refute_includes response.body, "BEGIN:VEVENT"
  end

  test "unavailable events return 404 through the production exception handler" do
    original = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    deleted = trips(:yosemite)
    deleted.soft_delete!

    [ trips(:jtree).id, deleted.id, Trip.maximum(:id) + 1 ].each do |id|
      get calendar_trip_url(id, format: :ics)

      assert_response :not_found
      assert_empty response.body
    end
  ensure
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = original
  end

  test "index offers subscription and feed URL and event page offers single download" do
    get trips_url
    assert_response :success
    assert_select "a[href='#{calendar_trips_url(format: :ics, protocol: 'webcal')}']", text: "Subscribe to all events"
    assert_select "a[href='#{calendar_trips_url(format: :ics)}']", text: "iCal feed URL"

    get trip_url(trips(:yosemite))
    assert_response :success
    assert_select "a[href='#{calendar_trip_path(trips(:yosemite), format: :ics)}']", text: "Add to calendar (.ics)"
  end
end
