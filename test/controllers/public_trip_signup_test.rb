require "test_helper"

class PublicTripSignupTest < ActionDispatch::IntegrationTest
  test "root renders and links to trips" do
    get root_url

    assert_response :success
    assert_select "h1", text: /Yosemite/
    assert_select "a[href='#{trips_path}']", text: /View trips/
  end

  test "trips index shows published trips and hides unpublished trips" do
    get trips_url

    assert_response :success
    assert_select "a", text: "Yosemite Valley Spring"
    assert_select "a", text: "Joshua Tree Winter", count: 0
  end

  test "public trip detail shows trip campsite and coordinator info" do
    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Yosemite Valley Spring"
    assert_select "h2", "Yosemite Valley, CA"
    assert_select "h2", "Campsite coordinator"
    assert_select ".details-list", text: /Alex Rivera/
    assert_select ".details-list", text: /alex@example.com/
    assert_select ".stats", text: /Signed up/
    assert_select ".stats", text: /Spaces available/
    assert_select ".stats", text: /Total capacity/
    assert_select "td", text: "A12"
    assert_select ".campsite-notes-row", text: /Close to bathrooms/
  end

  test "logged out signup redirects to login" do
    post trip_trip_signup_url(trips(:yosemite))

    assert_redirected_to new_session_url
  end

  test "user can register" do
    assert_difference "User.count", 1 do
      post registration_url, params: {
        user: {
          first_name: "Mina",
          last_name: "Park",
          email: "mina@example.com",
          phone: "555-0200",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to trips_url
    assert_not User.order(:created_at).last.member?
  end

  test "user can log in and log out" do
    post session_url, params: { email: "ALEX@EXAMPLE.COM", password: "password" }

    assert_redirected_to trips_url

    delete session_url

    assert_redirected_to root_url
  end

  test "logged in user can sign up for a trip" do
    log_in_as(users(:sam))

    assert_difference "TripSignup.count", 1 do
      post trip_trip_signup_url(trips(:yosemite))
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert TripSignup.find_by(trip: trips(:yosemite), user: users(:sam)).confirmed?
  end

  test "duplicate signup is blocked" do
    TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    assert_no_difference "TripSignup.count" do
      post trip_trip_signup_url(trips(:yosemite))
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "public attendee list abbreviates names and hides contact details" do
    TripSignup.create!(trip: trips(:yosemite), user: users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".attendee-list", text: /Sam L./
    assert_select ".attendee-list", text: /Sam Lee/, count: 0
    assert_select ".attendee-list", text: /555-0101/, count: 0
  end

  test "public trip detail shows waitlisted users separately" do
    trip = trips(:yosemite)
    trip.total_participant_capacity.times do |index|
      TripSignup.create!(trip: trip, user: User.create!(
        first_name: "Confirmed",
        last_name: "Participant#{index}",
        email: "public-confirmed#{index}@example.com",
        password: "password"
      ))
    end
    waitlisted_user = User.create!(first_name: "Willa", last_name: "Wait", email: "willa@example.com", password: "password")
    TripSignup.create!(trip: trip, user: waitlisted_user)

    get trip_url(trip)

    assert_response :success
    assert_select ".waitlist", text: /Waitlist/
    assert_select ".waitlist", text: /Willa W./
    assert_select ".waitlist", text: /Willa Wait/, count: 0
    assert_select ".waitlist", text: /willa@example.com/, count: 0
  end

  private

  def log_in_as(user)
    post session_url, params: { email: user.email, password: "password" }
    follow_redirect!
  end
end
