require "test_helper"

class MemberLinksTest < ActionDispatch::IntegrationTest
  test "all trip types reveal private resources and coordinator email only after login" do
    %w[camping day_trip class_trip].each do |type|
      trip = create_trip(type)
      ClimbingPartnerRequest.create!(trip: trip, user: users(:alex)) if type == "camping"
      get trip_url(trip)
      assert_response :success
      %w[whatsapp-token album-token prose-token alex@example.com 555-0100].each { |secret| assert_not_includes response.body, secret }
      assert_select "a[href='#{new_session_path(return_to: trip_path(trip))}']", text: /log in to reveal/i
      assert_select "a[href='https://forecast.weather.gov/public']"
      assert_select "a[href='https://example.com/public-guide']"

      log_in_as(users(:sam))
      get trip_url(trip)
      assert_response :success
      assert_select "a[href='https://chat.whatsapp.com/whatsapp-token']"
      assert_select "a[href='https://example.com/album-token']"
      assert_select "a[href='https://photos.app.goo.gl/prose-token']"
      assert_select "a[href='mailto:alex@example.com']" unless type == "class_trip"
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_select "meta[name=turbo-cache-control][content=no-cache]"
      delete session_url
    end
  end

  test "content pages and global liability text gate embedded member links" do
    ContentPage.current!("what_to_expect").update!(body: "[Photos](https://photos.app.goo.gl/content-token)\n\nhttps://chat.whatsapp.com/plain-token")
    SiteSetting.current.update!(liability_warning: "Contact mailto:coordinator@example.com or https://chat.whatsapp.com/footer-token")
    [ root_url, trips_url, what_to_expect_trips_url ].each do |url|
      get url
      assert_response :success
      %w[content-token plain-token coordinator@example.com footer-token].each { |secret| assert_not_includes response.body, secret }
    end
    log_in_as(users(:sam))
    get what_to_expect_trips_url
    assert_includes response.body, "content-token"
    assert_includes response.body, "plain-token"
    get root_url
    assert_includes response.body, "footer-token"
  end

  test "plain trip instructions gate contact links but keep public maps" do
    trip = create_trip("day_trip")
    trip.update!(late_arrival_instructions: "https://chat.whatsapp.com/late-token or mailto:late@example.com", carpool_meeting_spot: "Meet at https://maps.google.com/public or https://photos.google.com/share/carpool-token")
    get trip_url(trip)
    %w[late-token late@example.com carpool-token].each { |secret| assert_not_includes response.body, secret }
    assert_select "a[href='https://maps.google.com/public']"
    log_in_as(users(:sam))
    get trip_url(trip)
    %w[late-token late@example.com carpool-token].each { |secret| assert_includes response.body, secret }
  end

  test "public headings cards and content subtitles cannot leak member links" do
    trip = create_trip("day_trip")
    trip.update!(name: "Outing https://chat.whatsapp.com/name-token", location: "https://example.com/album-token", sun_exposure: "https://photos.app.goo.gl/sun-token")
    [ trips_url, trip_url(trip) ].each do |url|
      get url
      %w[name-token album-token sun-token].each { |secret| assert_not_includes response.body, secret }
    end
    trip.update!(status: "archived")
    get past_trips_trips_url
    %w[name-token album-token].each { |secret| assert_not_includes response.body, secret }
    ContentPage.current!("what_to_expect").update!(title: "https://chat.whatsapp.com/title-token", subtitle: "https://photos.app.goo.gl/subtitle-token")
    get what_to_expect_trips_url
    %w[title-token subtitle-token].each { |secret| assert_not_includes response.body, secret }
  end

  test "user edited participant names cannot expose member links on public lists" do
    users(:sam).update!(first_name: "https://chat.whatsapp.com/participant-token")
    users(:alex).update!(first_name: "name-contact@example.com")
    camping_trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam), status: "confirmed")
    create_waitlisted_signup!(trip: camping_trip, user: users(:alex))
    ClimbingPartnerRequest.create!(trip: camping_trip, user: users(:sam))
    spot = campsite.parking_spots.find_or_initialize_by(position: 1)
    spot.update!(status: "assigned", assigned_campsite_signup: signup)
    day_trip = create_trip("day_trip")
    DayTripSignup.create!(trip: day_trip, user: users(:sam), climbing_abilities: [ "lead" ])
    DayTripSignup.create!(trip: day_trip, user: users(:alex), climbing_abilities: [ "lead" ], status: "waitlisted")
    class_trip = create_trip("class_trip")
    ClassSignup.create!(trip: class_trip, user: users(:sam))

    [ camping_trip, day_trip, class_trip ].each do |trip|
      get trip_url(trip)
      assert_response :success
      %w[participant-token name-contact@example.com].each { |secret| assert_not_includes response.body, secret }
    end

    log_in_as(users(:sam))
    [ camping_trip, day_trip, class_trip ].each do |trip|
      get trip_url(trip)
      assert_response :success
      assert_includes response.body, "participant-token"
    end
  end

  private

  def create_trip(type)
    Trip.create!(
      trip_type: type, name: "Member resources", location: "Castle Rock", status: "published",
      start_date: Date.new(2026, 10, 12), end_date: Date.new(2026, 10, 13),
      meeting_time: "09:00", meeting_location: "Trailhead", meeting_location_url: "https://maps.google.com/public",
      late_arrival_instructions: "Meet at the crag", climbing_types: [ "sport" ], participant_capacity: 8,
      partner_company: partner_companies(:vertical_world), class_signup_url: "https://example.com/classes/anchors", class_original_price: "250",
      campsite_coordinator: users(:alex), whatsapp_group: "https://chat.whatsapp.com/whatsapp-token", photo_album_url: "https://example.com/album-token",
      weather_url: "https://forecast.weather.gov/public",
      description: "[Album](https://example.com/album-token) and [photos](https://photos.app.goo.gl/prose-token) and [guide](https://example.com/public-guide)"
    )
  end
end
