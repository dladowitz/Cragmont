require "test_helper"

class PublicCampsiteSignupTest < ActionDispatch::IntegrationTest
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
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /Upper Pines/
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /site A12/
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /Close to bathrooms/
  end

  test "logged out signup redirects to login" do
    post signup_url_for

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

  test "logged in user can sign up for a campsite" do
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_difference "CampsiteSignup.count", 1 do
      post signup_url_for, params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    signup = CampsiteSignup.find_by(trip: trips(:yosemite), user: users(:sam))
    assert_equal campsites(:yosemite_a), signup.campsite
    assert_equal Date.new(2026, 6, 13), signup.arrival_date
    assert_equal Date.new(2026, 6, 15), signup.checkout_date
    assert_equal 2, signup.night_count
    assert signup.confirmed?
    assert signup.waiver_signed?
    assert signup.waiver_signature_image.attached?
    assert signup.waiver_document.attached?
    assert_match(/\A\d{4}-\d{2}-\d{2}-Sam-Lee-Yosemite-Valley-Spring-A12-#{signup.id}\.pdf\z/, signup.waiver_document.filename.to_s)
    assert_equal users(:sam).full_name, signup.waiver_signer_name
    assert signup.waiver_acknowledged_at.present?
    assert_equal TripSignupWaiver.acknowledgement_text, signup.waiver_acknowledgement_text
    assert_equal TripSignupWaiver.text, signup.waiver_text
  end

  test "logged in user can sign up with minors" do
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 1 do
      assert_difference "CampsiteSignupMinor.count", 2 do
        post signup_url_for, params: waiver_signature_params_with_minors(
          { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" },
          { first_name: "Nora", last_name: "Lee", age: 14, relationship: "Niece" }
        )
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 2, signup.campsite_signup_minors.size
    assert_includes signup.waiver_acknowledgement_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert_includes signup.waiver_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert signup.waiver_document.attached?
  end

  test "signup with minors requires minor information" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please enter minor information before signing up.", flash[:alert]
  end

  test "signup with minors rejects incomplete minor information" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors(
        { first_name: "Mika", last_name: "", age: 12, relationship: "Child" }
      )
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "signup with minors rejects more than two minors" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors(
        { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" },
        { first_name: "Nora", last_name: "Lee", age: 14, relationship: "Niece" },
        { first_name: "Tali", last_name: "Lee", age: 10, relationship: "Child" }
      )
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "signup with minors rejects adult age" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors(
        { first_name: "Mika", last_name: "Lee", age: 18, relationship: "Child" }
      )
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "logged in user cannot sign up without signing waiver" do
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: { campsite_signup: { waiver_acknowledged_at: Time.current.iso8601 } }
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please sign the waiver before signing up.", flash[:alert]
  end

  test "logged in user cannot sign up without agreeing to acknowledgement" do
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: { campsite_signup: { waiver_signature_data: SIGNATURE_DATA_URL } }
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please agree to the waiver acknowledgement before signing up.", flash[:alert]
  end

  test "logged in user cannot sign up with malformed signature" do
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: { campsite_signup: { waiver_signature_data: "not-a-signature", waiver_acknowledged_at: Time.current.iso8601 } }
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please sign the waiver before signing up.", flash[:alert]
  end

  test "logged in user cannot sign up without attendance dates" do
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup].delete(:arrival_date)
    params[:campsite_signup].delete(:checkout_date)

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_match(/Arrival date can't be blank/, flash[:alert])
    assert_match(/Checkout date can't be blank/, flash[:alert])
  end

  test "logged in user cannot sign up with attendance dates outside campsite dates" do
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:arrival_date] = "2026-06-11"
    params[:campsite_signup][:checkout_date] = "2026-06-16"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_match(/Arrival date must be on or after the campsite arrival date/, flash[:alert])
    assert_match(/Checkout date must be on or before the campsite checkout date/, flash[:alert])
  end

  test "duplicate signup for another campsite in the same trip is blocked" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsites(:yosemite_b)), params: waiver_signature_params
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "confirmed user can remove themself from a campsite" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", -1 do
      delete signup_url_for
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_nil CampsiteSignup.find_by(id: signup.id)
  end

  test "waitlisted user can remove themself from a campsite" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.waitlisted!
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", -1 do
      delete signup_url_for
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_nil CampsiteSignup.find_by(id: signup.id)
  end

  test "trip detail shows remove modal for signed in participant" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: Date.new(2026, 6, 13))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Remove me from this campsite"
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /Jun 13-Jun 15/
    assert_select "dialog.signup-modal h2", text: "Remove yourself from this campsite?"
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Remove me from this campsite/
  end

  test "trip detail shows waitlist remove modal for signed in waitlisted participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.waitlisted!
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Remove me from the waitlist"
    assert_select "dialog.signup-modal h2", text: "Remove yourself from the waitlist?"
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Remove me from the waitlist/
  end

  test "trip detail shows signup modal for logged in non participant" do
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Sign up for this campsite"
    assert_select "dialog.signup-modal"
    assert_select ".signup-kind-options", text: /I am signing up for myself/
    assert_select ".signup-kind-options", text: /I am signing up for myself and minors/
    assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
    assert_select "input[type='date'][name='campsite_signup[arrival_date]'][min='2026-06-12'][max='2026-06-14']"
    assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
    assert_select "input[type='date'][name='campsite_signup[checkout_date]'][min='2026-06-13'][max='2026-06-15']"
    assert_select ".minor-fields", text: /Minor information/
    assert_select "button", text: "Next"
    assert_select ".waiver-intro", text: /not a teaching or instructional organization/
    assert_select "button", text: "Agree and Sign Waiver"
    assert_select ".waiver-text", text: /READ THIS DOCUMENT CAREFULLY BEFORE SIGNING/
    assert_select ".waiver-text", text: /YOU ARE GIVING UP IMPORTANT LEGAL RIGHTS/
    assert_select "canvas.signature-pad"
    assert_select "button", text: "Clear signature"
    assert_select "input[type='hidden'][name='campsite_signup[waiver_signature_data]']"
    assert_select "input[type='hidden'][name='campsite_signup[waiver_acknowledged_at]']"
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Pay Now and Sign Up/
  end

  test "trip detail disables other campsite signup buttons after signup" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /You are confirmed for this campsite/
    assert_select "#campsite-#{campsites(:yosemite_b).id}" do
      assert_select "button[disabled]", text: "Already signed up"
      assert_select ".muted", text: /already signed up for another campsite/
    end
  end

  test "trip detail shows waitlist signup button when campsite has no spaces available" do
    fill_campsite_capacity(campsites(:yosemite_a), "waitlist-button")
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select "button", text: "Sign up for the waitlist"
      assert_select ".danger-stat", text: /0/
      assert_select ".signup-modal h2", text: "Sign up for campsite waitlist"
    end
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Sign up for Waitlist/
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Pay Now and Sign Up/, count: 0
  end

  test "logged in user can sign waiver and join waitlist" do
    fill_campsite_capacity(campsites(:yosemite_a), "waitlist-signup")
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 1 do
      post signup_url_for, params: waiver_signature_params
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert signup.waiver_signed?
  end

  test "minor under configured age limit does not consume capacity" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "under-capacity", count: campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    post signup_url_for, params: waiver_signature_params_with_minors(
      { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" }
    )

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 6, campsite.reload.confirmed_signup_count
    assert_equal 1, campsite.confirmed_uncounted_minor_count
  end

  test "minor at configured age limit consumes capacity" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "teen-capacity", count: campsite.participant_capacity - 2)
    log_in_as(users(:sam))

    post signup_url_for, params: waiver_signature_params_with_minors(
      { first_name: "Nora", last_name: "Lee", age: 13, relationship: "Niece" }
    )

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 6, campsite.reload.confirmed_signup_count
    assert_equal 0, campsite.available_participant_capacity
  end

  test "whole group is waitlisted when capacity cannot fit counting minors" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "group-waitlist", count: campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    post signup_url_for, params: waiver_signature_params_with_minors(
      { first_name: "Mika", last_name: "Lee", age: 13, relationship: "Child" },
      { first_name: "Nora", last_name: "Lee", age: 14, relationship: "Niece" }
    )

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_equal 5, campsite.reload.confirmed_signup_count
  end

  test "trip detail shows almost full warning at sixty percent capacity" do
    trip = trips(:yosemite)
    6.times do |index|
      create_campsite_signup!(campsite: campsites(:yosemite_a), user: User.create!(
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

  test "public participant list abbreviates names and hides contact details" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: Date.new(2026, 6, 13))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".participant-list", text: /Sam L\. \(Jun 13-Jun 15\)/
    assert_select ".participant-list", text: /Sam Lee/, count: 0
    assert_select ".participant-list", text: /555-0101/, count: 0
  end

  test "public participant list summarizes minors without names" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".participant-list", text: /Sam L\. \+ 1 minor \(Jun 12-Jun 15\)/
    assert_select ".participant-list", text: /Mika/, count: 0
  end

  test "public stats split out uncounted minors" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".split-signup-stat section:first-child", text: /1/
    assert_select ".split-signup-stat section:first-child", text: /Signed up/
    assert_select ".split-signup-stat section:last-child", text: /1/
    assert_select ".split-signup-stat section:last-child", text: /Under #{SiteSetting.current.uncounted_minor_age_limit}/
  end

  test "public trip detail shows waitlisted users separately" do
    trip = trips(:yosemite)
    fill_campsite_capacity(campsites(:yosemite_a), "public-confirmed")
    waitlisted_user = User.create!(first_name: "Willa", last_name: "Wait", email: "willa@example.com", password: "password")
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: waitlisted_user)

    get trip_url(trip)

    assert_response :success
    assert_select ".waitlisted-signups-section", text: /Waitlist/
    assert_select ".waitlisted-signups-section", text: /Willa W\. \(Jun 12-Jun 15\)/
    assert_select ".waitlisted-signups-section", text: /Willa Wait/, count: 0
    assert_select ".waitlisted-signups-section", text: /willa@example.com/, count: 0
  end

  private

  def log_in_as(user)
    post session_url, params: { email: user.email, password: "password" }
    follow_redirect!
  end

  def waiver_signature_params_with_minors(*minor_attributes)
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:signup_kind] = "with_minors"
    params[:campsite_signup][:campsite_signup_minors_attributes] = minor_attributes.each_with_index.to_h do |attributes, index|
      [ index.to_s, attributes ]
    end
    params
  end

  def signup_url_for(campsite = campsites(:yosemite_a))
    trip_campsite_campsite_signup_url(campsite.trip, campsite)
  end

  def signup_path_for(campsite = campsites(:yosemite_a))
    trip_campsite_campsite_signup_path(campsite.trip, campsite)
  end

  def fill_campsite_capacity(campsite, prefix, count: campsite.participant_capacity)
    count.times do |index|
      create_campsite_signup!(
        campsite: campsite,
        user: User.create!(
          first_name: "Confirmed",
          last_name: "#{prefix.camelize}#{index}",
          email: "#{prefix}-#{campsite.id}-#{index}@example.com",
          password: "password"
        )
      )
    end
  end
end
