require "test_helper"

class PublicTripSignupTest < ActionDispatch::IntegrationTest
  test "root renders and links to trips" do
    get root_url

    assert_response :success
    assert_select "h1", text: "Climbing"
    assert_select "h1", text: "Camping"
    assert_select "h1", text: "Community"
    assert_select "p", text: /Yosemite/
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
    assert_select ".stats .success-stat", text: /10/
    assert_select ".stats .success-stat", text: /Spaces available/
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
      post trip_trip_signup_url(trips(:yosemite)), params: waiver_signature_params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    signup = TripSignup.find_by(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert signup.waiver_signed?
    assert signup.waiver_signature_image.attached?
    assert signup.waiver_document.attached?
    assert_equal users(:sam).full_name, signup.waiver_signer_name
    assert_equal TripSignupWaiver.text, signup.waiver_text
  end

  test "logged in user cannot sign up without signing waiver" do
    log_in_as(users(:sam))

    assert_no_difference "TripSignup.count" do
      post trip_trip_signup_url(trips(:yosemite))
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please sign the waiver before signing up.", flash[:alert]
  end

  test "logged in user cannot sign up with malformed signature" do
    log_in_as(users(:sam))

    assert_no_difference "TripSignup.count" do
      post trip_trip_signup_url(trips(:yosemite)), params: { trip_signup: { waiver_signature_data: "not-a-signature" } }
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please sign the waiver before signing up.", flash[:alert]
  end

  test "duplicate signup is blocked" do
    TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    assert_no_difference "TripSignup.count" do
      post trip_trip_signup_url(trips(:yosemite)), params: waiver_signature_params
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "confirmed user can remove themself from a trip" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    assert_difference "TripSignup.count", -1 do
      delete trip_trip_signup_url(trips(:yosemite))
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_nil TripSignup.find_by(id: signup.id)
  end

  test "waitlisted user can remove themself from a trip" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    signup.waitlisted!
    log_in_as(users(:sam))

    assert_difference "TripSignup.count", -1 do
      delete trip_trip_signup_url(trips(:yosemite))
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_nil TripSignup.find_by(id: signup.id)
  end

  test "trip detail shows remove modal for signed in participant" do
    TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Remove me from this trip"
    assert_select "dialog.signup-modal h2", text: "Remove yourself from this trip?"
    assert_select "form[action='#{trip_trip_signup_path(trips(:yosemite))}'][method='post']", text: /Remove me from this trip/
  end

  test "trip detail shows waitlist remove modal for signed in waitlisted participant" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    signup.waitlisted!
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Remove me from the waitlist"
    assert_select "dialog.signup-modal h2", text: "Remove yourself from the waitlist?"
    assert_select "form[action='#{trip_trip_signup_path(trips(:yosemite))}'][method='post']", text: /Remove me from the waitlist/
  end

  test "trip detail shows signup modal for logged in non participant" do
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Sign up for this trip"
    assert_select "dialog.signup-modal"
    assert_select ".waiver-text", text: /#{Regexp.escape(TripSignupWaiver.text)}/
    assert_select "canvas.signature-pad"
    assert_select "button", text: "Clear signature"
    assert_select "input[type='hidden'][name='trip_signup[waiver_signature_data]']"
    assert_select "form[action='#{trip_trip_signup_path(trips(:yosemite))}'][method='post']", text: /Pay Now and Sign Up/
  end

  test "trip detail shows waitlist signup button when no spaces are available" do
    trip = trips(:yosemite)
    trip.total_participant_capacity.times do |index|
      TripSignup.create!(trip: trip, user: User.create!(
        first_name: "Confirmed",
        last_name: "WaitlistButton#{index}",
        email: "waitlist-button#{index}@example.com",
        password: "password"
      ))
    end
    log_in_as(users(:sam))

    get trip_url(trip)

    assert_response :success
    assert_select "button", text: "Sign up for the waitlist"
    assert_select "button", text: "Sign up for this trip", count: 0
    assert_select ".trip-title-line .status", text: "Trip Full"
    assert_select ".stats .danger-stat", text: /0/
    assert_select ".stats .danger-stat", text: /Spaces available/
    assert_select ".signup-modal h2", text: "Sign up for WAITLIST"
    assert_select "form[action='#{trip_trip_signup_path(trip)}'][method='post']", text: /Sign up for Waitlist/
    assert_select "form[action='#{trip_trip_signup_path(trip)}'][method='post']", text: /Pay Now and Sign Up/, count: 0
  end

  test "logged in user can sign waiver and join waitlist" do
    trip = trips(:yosemite)
    trip.total_participant_capacity.times do |index|
      TripSignup.create!(trip: trip, user: User.create!(
        first_name: "Confirmed",
        last_name: "WaitlistSignup#{index}",
        email: "waitlist-signup#{index}@example.com",
        password: "password"
      ))
    end
    log_in_as(users(:sam))

    assert_difference "TripSignup.count", 1 do
      post trip_trip_signup_url(trip), params: waiver_signature_params
    end

    signup = TripSignup.find_by!(trip: trip, user: users(:sam))
    assert signup.waitlisted?
    assert signup.waiver_signed?
  end

  test "trip detail shows almost full warning at sixty percent capacity" do
    trip = trips(:yosemite)
    6.times do |index|
      TripSignup.create!(trip: trip, user: User.create!(
        first_name: "Almost",
        last_name: "FullView#{index}",
        email: "almost-full-view#{index}@example.com",
        password: "password"
      ))
    end

    get trip_url(trip)

    assert_response :success
    assert_select ".trip-title-line .warning-status", text: "Almost Full"
    assert_select ".trip-title-line .danger-status", count: 0
    assert_select ".stats .warning-stat", text: /4/
    assert_select ".stats .warning-stat", text: /Spaces available/
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
