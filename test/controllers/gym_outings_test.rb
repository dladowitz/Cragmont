require "test_helper"

class GymOutingsTest < ActionDispatch::IntegrationTest
  setup do
    @attributes = {
      trip_type: "gym_outing", name: "Friday gym laps", location: "Movement, San Francisco",
      start_date: "2026-10-16", meeting_time: "18:00", end_time: "20:00",
      status: "published", participant_capacity: 2
    }
    @trip = Trip.create!(@attributes)
  end

  test "admins can choose create and edit a gym outing without outdoor fields" do
    log_in_as(users(:alex))
    get new_admin_trip_url
    assert_select "a[href='#{new_admin_trip_path(trip_type: 'gym_outing')}']", text: "Gym outing"

    get new_admin_trip_url(trip_type: "gym_outing")
    assert_response :success
    assert_select "h2", text: "New gym outing"
    assert_select "input[name='trip[trip_type]'][value='gym_outing']"
    assert_select "label[for='trip_name']", text: /Gym outing name/
    assert_select "input[name='trip[meeting_time]'][required]"
    assert_select "input[name='trip[participant_capacity]'][min='1'][required]"
    %w[end_date climbing_types mountain_project_url guide_book_url sun_exposure weather_url late_arrival_instructions].each do |field|
      assert_select "input[name^='trip[#{field}]'], textarea[name='trip[#{field}]']", count: 0
    end

    assert_difference "Trip.count", 1 do
      post admin_trips_url, params: { trip: @attributes.merge(name: "Gym crew") }
    end
    trip = Trip.order(:created_at).last
    assert_redirected_to admin_trip_url(trip)
    assert trip.gym_outing?
    assert_equal trip.start_date, trip.end_date

    patch admin_trip_url(trip), params: { trip: { name: "Gym crew evening", start_date: "2026-10-17", meeting_time: "19:00" } }
    assert_redirected_to admin_trip_url(trip)
    trip.reload
    assert_equal "Gym crew evening", trip.name
    assert_equal trip.start_date, trip.end_date
    assert_equal "19:00", trip.meeting_time.strftime("%H:%M")

    get admin_trip_url(trip)
    assert_response :success
    assert_select "h2", text: "Gym Plan"
    assert_select "h2", text: "Participants"
    assert_select "h2", text: "Campsites", count: 0
  end

  test "gym outing appears publicly with its schedule and gym specific registration" do
    get trips_url
    assert_select ".trip-card[href='#{trip_path(@trip)}'] .trip-type-badge", text: "Gym Outing"
    get trip_url(@trip)
    assert_response :success
    assert_select "h2", text: "Gym Plan"
    assert_select "dd", text: "Movement, San Francisco"
    assert_select "dd", text: "6:00pm"
    assert_select "dd", text: "8:00pm"
    assert_select "a", text: "Log in to sign up"
    assert_select ".trips-faq-callout", count: 0
    assert_select "dt", text: "Types of climbing", count: 0
    assert_select "dt", text: "If you are running late", count: 0
    assert_not_includes response.body, Trip::DEFAULT_LATE_ARRIVAL_INSTRUCTIONS
    assert_select "p", text: /gym’s admission/

    log_in_as(users(:sam))
    get trip_url(@trip)
    assert_select "form[action='#{trip_day_trip_signup_path(@trip)}']"
    assert_select "input[name='day_trip_signup[with_minor]']"
    assert_select "[data-climbing-ability-group]", count: 0
    assert_select "legend", text: "Gear I plan to bring", count: 0
  end

  test "gym signup requires login and waiver then counts a minor and waitlists overflow" do
    assert_no_difference "DayTripSignup.count" do
      post trip_day_trip_signup_url(@trip)
    end
    assert_redirected_to new_session_url

    log_in_as(users(:sam))
    assert_no_difference "DayTripSignup.count" do
      post trip_day_trip_signup_url(@trip)
    end
    assert_match /waiver acknowledgement/, flash[:alert]

    post trip_day_trip_signup_url(@trip), params: { day_trip_signup: {
      with_minor: "1", day_trip_signup_minors_attributes: { "0" => { first_name: "Little", last_name: "Climber", age: 10, relationship: "Child" } },
      waiver_signature_data: SIGNATURE_DATA_URL, waiver_acknowledged_at: Time.current.iso8601,
      rope_60m: "1", crash_pad_count: "2"
    } }
    assert_redirected_to trip_url(@trip)
    signup = @trip.day_trip_signups.find_by!(user: users(:sam))
    assert signup.confirmed?
    assert signup.waiver_signed?
    assert_equal 2, signup.party_capacity_count
    assert_not signup.rope_60m?
    assert_equal 0, signup.crash_pad_count
    assert @trip.reload.capacity_full?
    assert_match /gym outing/, flash[:notice]

    log_in_as(users(:alex))
    post trip_day_trip_signup_url(@trip), params: { day_trip_signup: {
      waiver_signature_data: SIGNATURE_DATA_URL, waiver_acknowledged_at: Time.current.iso8601
    } }
    assert @trip.day_trip_signups.find_by!(user: users(:alex)).waitlisted?
    assert_equal 2, @trip.reload.confirmed_capacity_count

    get admin_trip_url(@trip)
    assert_response :success
    assert_select "td", text: users(:sam).full_name
    assert_select "th", text: "Bringing Gear", count: 0
    patch move_to_waitlist_admin_trip_day_trip_signup_url(@trip, signup)
    assert signup.reload.waitlisted?
    assert_equal 2, @trip.reload.available_participant_capacity

    delete trip_day_trip_signup_url(@trip)
    assert_nil @trip.day_trip_signups.find_by(user: users(:alex))
  end

  test "archived draft and deleted gym outings cannot accept participants" do
    log_in_as(users(:sam))
    [ { status: "archived" }, { status: "draft" }, { status: "published", deleted_at: Time.current } ].each do |attributes|
      @trip.update!(attributes)
      assert_no_difference "DayTripSignup.count" do
        post trip_day_trip_signup_url(@trip)
      end
      assert_response :not_found
    end
  end

  test "archived gym outings show participant counts instead of campsites" do
    DayTripSignup.create!(trip: @trip, user: users(:sam), climbing_abilities: [ "none" ])
    @trip.update!(status: "archived")

    get past_trips_trips_url
    assert_response :success
    assert_select ".archived-trip-row[href='#{trip_path(@trip)}']" do
      assert_select "dt", text: "Participants"
      assert_select "dd", text: "1"
      assert_select "dt", text: "Sites", count: 0
    end
  end

  test "gym signup counts young minors in the browser capacity warning and on the server" do
    @trip.update!(participant_capacity: 1)
    log_in_as(users(:sam))
    get trip_url(@trip)
    assert_response :success
    assert_select "form[action='#{trip_day_trip_signup_path(@trip)}'][data-signature-available-participant-capacity-value='1'][data-signature-uncounted-minor-age-limit-value='0']"

    post trip_day_trip_signup_url(@trip), params: { day_trip_signup: {
      with_minor: "1", day_trip_signup_minors_attributes: { "0" => { first_name: "Little", last_name: "Climber", age: 5, relationship: "Child" } },
      waiver_signature_data: SIGNATURE_DATA_URL, waiver_acknowledged_at: Time.current.iso8601
    } }
    assert_redirected_to trip_url(@trip)
    signup = @trip.day_trip_signups.find_by!(user: users(:sam))
    assert signup.waitlisted?
    assert_equal 2, signup.party_capacity_count
  end

  test "gym calendar subscriptions stay public while member links require login" do
    @trip.update!(
      whatsapp_group: "https://chat.whatsapp.com/gym-private-invite",
      photo_album_url: "https://example.com/gym-private-album",
      description: "Photos: https://example.com/gym-private-album"
    )
    get trip_url(@trip)
    assert_response :success
    assert_not_includes response.body, "gym-private-invite"
    assert_not_includes response.body, "gym-private-album"
    assert_select "a[href='#{new_session_path(return_to: trip_path(@trip))}']", text: /log in to reveal/
    assert_select "a[href='#{calendar_trip_path(@trip, format: :ics)}']"

    get calendar_trips_url(format: :ics)
    assert_response :success
    assert_includes response.body, "UID:trip-#{@trip.id}@cragmontclimbing.com"
    assert_includes response.body, "DTSTART:20261017T010000Z"
    assert_includes response.body, "DTEND:20261017T030000Z"
    assert_not_includes response.body, "gym-private"

    log_in_as(users(:sam))
    get trip_url(@trip)
    assert_select "a[href='#{@trip.whatsapp_group}']"
    assert_select "a[href='#{@trip.photo_album_url}']"
    assert_equal "private, no-store", response.headers["Cache-Control"]

    get calendar_trip_url(@trip, format: :ics)
    assert_response :success
    assert_not_includes response.body, "gym-private"
  end
end
