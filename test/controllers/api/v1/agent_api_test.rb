require "test_helper"

class Api::V1::AgentApiTest < ActionDispatch::IntegrationTest
  test "OpenAPI description is discoverable without a session" do
    get "/.well-known/openapi.json"
    assert_redirected_to "/openapi.json"

    get "/openapi.json"
    assert_response :success
    assert_equal "3.1.0", response.parsed_body.fetch("openapi")
    assert response.parsed_body.fetch("components").fetch("securitySchemes").key?("adminSession")
  end

  test "API requires a signed-in admin browser session" do
    get api_v1_trips_url
    assert_response :unauthorized

    log_in_as(users(:sam))
    get api_v1_trips_url
    assert_response :forbidden
  end

  test "trip admin can create a draft trip and make a partial edit" do
    log_in_as(users(:alex))
    post api_v1_trips_url, params: {
      trip: { name: "Granite Weekend", location: "Yosemite", start_date: "2026-12-11", end_date: "2026-12-13", trip_type: "camping" }
    }, as: :json

    assert_response :created
    trip = Trip.find(response.parsed_body.fetch("trip").fetch("id"))
    assert_equal "draft", trip.status
    assert_equal [ trip.id ], response.parsed_body.fetch("created_trip_ids")

    patch api_v1_trip_url(trip), params: { trip: { name: "Granite and Campfire Weekend" } }, as: :json
    assert_response :success
    assert_equal "Granite and Campfire Weekend", trip.reload.name

    patch api_v1_trip_url(trip), params: { trip: { deleted_at: Time.current.iso8601 } }, as: :json
    assert_response :bad_request
    assert_equal false, trip.reload.deleted?

    get api_v1_trip_url(trip)
    assert_response :success
    assert_equal trip.id, response.parsed_body.fetch("trip").fetch("id")

    get api_v1_trips_url, params: { before_id: [ trip.id ] }
    assert_response :bad_request
  end

  test "coordinator can read and edit only assigned trips, not create trips or campgrounds" do
    trips(:jtree).update!(campsite_coordinator: users(:sam))
    log_in_as(users(:sam))

    get api_v1_trips_url
    assert_response :success
    assert_equal [ trips(:jtree).id ], response.parsed_body.fetch("trips").map { |trip| trip.fetch("id") }

    patch api_v1_trip_url(trips(:jtree)), params: { trip: { description: "Updated by coordinator" } }, as: :json
    assert_response :success
    assert_equal "Updated by coordinator", trips(:jtree).reload.description

    post api_v1_trips_url, params: { trip: { name: "Nope" } }, as: :json
    assert_response :forbidden

    get api_v1_campgrounds_url
    assert_response :success
    post api_v1_campgrounds_url, params: { campground: { name: "Nope", location: "CA" } }, as: :json
    assert_response :forbidden
  end

  test "admin can read and load campsite reservations within a camping trip" do
    log_in_as(users(:alex))
    trip = trips(:jtree)

    get api_v1_trip_campsites_url(trip)
    assert_response :success
    assert_equal "H4", response.parsed_body.fetch("campsites").first.fetch("site_number")

    post api_v1_trip_campsites_url(trip), params: {
      campsite: {
        campground_id: campgrounds(:hidden_valley).id, site_number: "H5",
        arrival_date: "2026-12-04", checkout_date: "2026-12-07",
        participant_capacity: 4, car_capacity: 1, registration_number: "CONF-55", registration_fee: "35.00"
      }
    }, as: :json

    assert_response :created
    campsite = Campsite.find(response.parsed_body.fetch("campsite").fetch("id"))
    assert_equal "CONF-55", campsite.registration_number
    assert_equal 3500, campsite.registration_fee_cents

    patch api_v1_trip_campsite_url(trip, campsite), params: { campsite: { notes: "Near trailhead" } }, as: :json
    assert_response :success
    assert_equal "Near trailhead", campsite.reload.notes

    patch api_v1_trip_campsite_url(trips(:yosemite), campsite), params: { campsite: { notes: "Wrong trip" } }, as: :json
    assert_response :not_found

    post api_v1_trip_campsites_url(trip), params: { campsite: { registration_fee: "not a number" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "API rejects invalid trips and does not add campsites to non-camping trips" do
    log_in_as(users(:alex))
    post api_v1_trips_url, params: { trip: { name: "Incomplete" } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body.fetch("errors").any?

    post api_v1_trips_url, params: { trip: {
      trip_type: "day_trip", name: "Local Rocks", location: "Berkeley", start_date: "2026-12-11",
      meeting_time: "09:00", meeting_location: "Trailhead", meeting_location_url: "https://example.com/map",
      late_arrival_instructions: "Meet at the trailhead", climbing_types: [ "sport" ]
    } }, as: :json
    assert_response :created
    day_trip = Trip.find(response.parsed_body.fetch("trip").fetch("id"))
    assert_equal [ "sport" ], day_trip.climbing_types

    post api_v1_trip_campsites_url(day_trip), params: { campsite: { site_number: "1" } }, as: :json
    assert_response :conflict
  end

  test "browser writes require the page CSRF token" do
    log_in_as(users(:alex))
    old_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get admin_trips_url
    csrf = css_select('meta[name="csrf-token"]').first["content"]

    post api_v1_trips_url, params: { trip: { name: "Missing CSRF" } }, as: :json
    assert_response :unprocessable_entity

    post api_v1_trips_url, params: {
      trip: { name: "Authenticated CSRF", location: "Berkeley", start_date: "2026-12-11", end_date: "2026-12-12", trip_type: "camping" }
    }, headers: { "X-CSRF-Token" => csrf }, as: :json
    assert_response :created
  ensure
    ActionController::Base.allow_forgery_protection = old_setting
  end
end
