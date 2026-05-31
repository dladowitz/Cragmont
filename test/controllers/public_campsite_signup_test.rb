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

  test "registration form has password visibility controls" do
    get new_registration_url

    assert_response :success
    assert_select ".password-visibility-field[data-controller='password-visibility']", count: 2
    assert_select "button.password-visibility-toggle[aria-label='Show password']", count: 2
    assert_select "input[type='password'][data-password-visibility-target='input']", count: 2
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

  test "logged in user can sign up with guests" do
    log_in_as(users(:sam))

    assert_difference "User.count", 2 do
      assert_difference "CampsiteSignup.count", 3 do
        post signup_url_for, params: waiver_signature_params_with_guests(
          { first_name: "Gina", last_name: "Guest", email: "gina-guest@example.com", phone: "555-0300" },
          { first_name: "Omar", last_name: "Guest", email: "omar-guest@example.com", phone: "" }
        )
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert signup.waiver_signed?
    assert_equal 2, signup.guest_signups.size
    assert_equal 3, signup.party_capacity_count
    signup.guest_signups.each do |guest_signup|
      assert guest_signup.confirmed?
      assert_equal signup, guest_signup.guest_of_signup
      assert_equal signup.campsite, guest_signup.campsite
      assert_equal signup.arrival_date, guest_signup.arrival_date
      assert_equal signup.checkout_date, guest_signup.checkout_date
      assert guest_signup.user.default_password?
      assert guest_signup.user.authenticate(User::DEFAULT_GUEST_PASSWORD)
      assert_not guest_signup.waiver_signed?
    end
  end

  test "guest signup reuses existing user email without resetting password" do
    existing_guest = User.create!(
      first_name: "Existing",
      last_name: "Guest",
      email: "existing-guest@example.com",
      phone: "555-0302",
      password: "custom-password",
      member: true
    )
    log_in_as(users(:sam))

    assert_no_difference "User.count" do
      assert_difference "CampsiteSignup.count", 2 do
        post signup_url_for, params: waiver_signature_params_with_guests(
          { first_name: "Changed", last_name: "Name", email: "EXISTING-GUEST@example.com", phone: "555-9999" }
        )
      end
    end

    guest_signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: existing_guest)
    assert guest_signup.guest?
    assert existing_guest.reload.authenticate("custom-password")
    assert_not existing_guest.default_password?
    assert_equal "Existing", existing_guest.first_name
    assert_equal "555-0302", existing_guest.phone
    assert existing_guest.member?
  end

  test "logged in user can sign up with minors and guests" do
    log_in_as(users(:sam))

    assert_difference "User.count", 1 do
      assert_difference "CampsiteSignup.count", 2 do
        assert_difference "CampsiteSignupMinor.count", 1 do
          post signup_url_for, params: waiver_signature_params_with_minors_and_guests(
            [ { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" } ],
            [ { first_name: "Gina", last_name: "Guest", email: "minor-party-guest@example.com", phone: "555-0301" } ]
          )
        end
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 1, signup.campsite_signup_minors.size
    assert_equal 1, signup.guest_signups.size
    assert_equal 2, signup.party_capacity_count
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
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
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

  test "trip detail shows waitlist remove action in waitlist table for signed in waitlisted participant" do
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".campsite-card button", text: "Remove me from the waitlist", count: 0
    assert_select ".trip-waitlist-section button.button.danger", text: "Remove Me"
    assert_select ".trip-waitlist-section dialog.signup-modal h2", text: "Remove me from the waitlist"
    assert_select ".trip-waitlist-section form[action='#{signup_path_for}'][method='post']", text: /Remove Me/
  end

  test "trip detail shows signup modal for logged in non participant" do
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Sign up for this campsite"
    assert_select "dialog.signup-modal"
    assert_select ".signup-kind-options", text: /Add adult/
    assert_select ".signup-kind-options", text: /Who are you signing up\?/, count: 0
    assert_select ".signup-kind-options", text: /Add minors \(under 18\)/
    assert_select "input[type='checkbox'][name='campsite_signup[with_minors]'][value='1']"
    assert_select "input[type='checkbox'][name='campsite_signup[with_guests]'][value='1']"
    assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
    assert_select "input[type='date'][name='campsite_signup[arrival_date]'][min='2026-06-12'][max='2026-06-14']"
    assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
    assert_select "input[type='date'][name='campsite_signup[checkout_date]'][min='2026-06-13'][max='2026-06-15']"
    assert_select "form.waiver-form[data-signature-available-participant-capacity-value='6'][data-signature-show-capacity-warning-value='true']"
    assert_select ".capacity-warning[hidden]", text: /You've exceeded the space available for this campsite\. Your party will be placed on the waitlist\./, count: 2
    assert_select ".guest-fields", text: /Adult information\s+\(Max 2\)/
    assert_select ".guest-fields .guest-field-row", count: 4
    assert_select ".guest-fields .guest-field-row[hidden]", count: 2
    assert_select ".guest-fields button.add-person-link", text: "Add another adult"
    assert_select "input[name='campsite_signup[guest_attributes][0][email]']"
    assert_select ".minor-fields", text: /Minor information\s+\(Max 2\)/
    assert_select ".minor-fields .minor-field-row", count: 4
    assert_select ".minor-fields .minor-field-row[hidden]", count: 2
    assert_select ".minor-fields button.add-person-link", text: "Add another minor"
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

  test "shared details link opens completion modal for signed in participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: nil, checkout_date: nil)
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite), complete_signup: signup.signed_id(purpose: :complete_participant_details))

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true']" do
      assert_select "dialog.signup-modal"
      assert_select "h2", "You've been added to the Yosemite Valley Spring trip."
      assert_select "p", "Please select dates you will be attending"
      assert_select ".participant-details-campsite-summary", text: /Upper Pines site A12/
      assert_select ".participant-details-campsite-summary", text: /Available June 12, 2026 to June 15, 2026/
      assert_select "form[action='#{signup_path_for}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='complete_participant_details']"
        assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
        assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
        assert_select ".signup-kind-options", count: 0
        assert_select ".guest-fields", count: 0
        assert_select "button", text: "Next"
        assert_select ".waiver-intro", text: /not a teaching or instructional organization/
        assert_select "button", text: "Agree and Sign Waiver"
        assert_select ".waiver-text", text: /READ THIS DOCUMENT CAREFULLY BEFORE SIGNING/
        assert_select "canvas.signature-pad"
        assert_select "button", text: "Complete"
      end
    end
  end

  test "admin-added participant can submit dates and waiver from shared details flow" do
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam), arrival_date: nil, checkout_date: nil)
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "complete_participant_details"
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Your trip details have been submitted.", flash[:notice]
    signup.reload
    assert_equal Date.new(2026, 6, 13), signup.arrival_date
    assert_equal Date.new(2026, 6, 15), signup.checkout_date
    assert signup.waiver_signed?
    assert signup.waiver_signature_image.attached?
    assert signup.waiver_document.attached?
  end

  test "guest shared link requires password setup before waiver completion" do
    campsite = campsites(:yosemite_a)
    primary_signup = create_campsite_signup!(campsite: campsite, user: users(:sam), arrival_date: Date.new(2026, 6, 13), checkout_date: Date.new(2026, 6, 15))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "guest-link@example.com",
      phone: "555-0303",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_campsite_signup!(
      campsite: campsite,
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1,
      arrival_date: primary_signup.arrival_date,
      checkout_date: primary_signup.checkout_date
    )
    token = guest_signup.signed_id(purpose: :complete_guest_details)

    get trip_url(trips(:yosemite), complete_signup: token)

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true']" do
      assert_select "h2", "Set your password"
      assert_select "form[action='#{guest_password_trip_campsite_campsite_signup_path(trips(:yosemite), campsite)}'][method='post']"
      assert_select "input[type='hidden'][name='complete_signup'][value='#{token}']"
      assert_select "input[type='password'][name='user[password]'][required]"
    end
    assert_select "form[action='#{signup_path_for(campsite)}'][method='post']", count: 0

    patch guest_password_trip_campsite_campsite_signup_url(trips(:yosemite), campsite), params: {
      complete_signup: token,
      user: {
        password: "guest-new-password",
        password_confirmation: "guest-new-password"
      }
    }

    assert_redirected_to trip_url(trips(:yosemite), complete_signup: token, anchor: "campsite-#{campsite.id}")
    assert_not guest_user.reload.default_password?
    assert guest_user.authenticate("guest-new-password")

    follow_redirect!

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true']" do
      assert_select "h2", "Gina Guest you've been added to the Yosemite Valley Spring trip by Sam Lee"
      assert_select "p", text: "Please select dates you will be attending", count: 0
      assert_select "form[action='#{signup_path_for(campsite)}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='complete_participant_details']"
        assert_select ".attendance-fields", text: /Confirm \(or change\) the nights Sam has selected for you\./
        assert_select "input[type='date'][name='campsite_signup[arrival_date]'][value='2026-06-13']"
        assert_select "input[type='date'][name='campsite_signup[checkout_date]'][value='2026-06-15']"
      end
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "complete_participant_details"
    params[:campsite_signup][:arrival_date] = "2026-06-14"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    post signup_url_for(campsite), params: params

    assert_redirected_to trip_url(trips(:yosemite))
    guest_signup.reload
    assert_equal Date.new(2026, 6, 14), guest_signup.arrival_date
    assert_equal Date.new(2026, 6, 15), guest_signup.checkout_date
    assert guest_signup.waiver_signed?
  end

  test "trip detail disables other campsite signup buttons after signup" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /You are confirmed for this campsite/
    assert_select "#campsite-#{campsites(:yosemite_b).id}" do
      assert_select ".muted", text: /already signed up for another campsite/
    end
  end

  test "trip detail shows waitlist signup button when campsite has no spaces available" do
    fill_campsite_capacity(campsites(:yosemite_a), "waitlist-button")
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select "button", text: "Join waitlist"
      assert_select ".danger-stat", text: /0/
      assert_select ".campsite-lock-notice", count: 0
      assert_select ".signup-modal h2", text: "Join trip waitlist"
      assert_select ".waitlist-form .minor-fields[hidden]", text: /Minor information/
      assert_select ".waitlist-form .minor-fields[data-required-dataset-key='requiredForMinor']"
      assert_select ".waitlist-form .minor-fields input[data-required-for-minor='true']", count: 8
      assert_select ".waitlist-form .guest-fields[hidden]", text: /Adult information/
      assert_select ".waitlist-form .guest-fields[data-required-dataset-key='requiredForGuest']"
      assert_select ".waitlist-form .guest-fields input[data-required-for-guest='true']", count: 6
    end
    assert_select "#campsite-#{campsites(:yosemite_b).id}" do
      assert_select "button", text: "Sign up for this campsite"
    end
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Join waitlist/
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Pay Now and Sign Up/, count: 0
  end

  test "logged in user can join waitlist without dates or waiver" do
    fill_campsite_capacity(campsites(:yosemite_a), "waitlist-signup")
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 1 do
      post signup_url_for, params: waitlist_signup_params
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_not signup.waiver_signed?
  end

  test "waitlisted user can sign up for a different open campsite" do
    full_campsite = campsites(:yosemite_a)
    open_campsite = campsites(:yosemite_b)
    fill_campsite_capacity(full_campsite, "waitlisted-open-campsite")
    log_in_as(users(:sam))

    post signup_url_for(full_campsite), params: waitlist_signup_params
    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_nil signup.campsite

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{full_campsite.id}" do
      assert_select "button[disabled]", text: "On waitlist"
    end
    assert_select "#campsite-#{open_campsite.id}" do
      assert_select "button", text: "Signup for campsite"
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move you from the waitlist to confirmed"
      assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='waitlist_direct_signup']"
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "waitlist_direct_signup"
    params[:campsite_signup][:arrival_date] = open_campsite.arrival_date.to_s
    params[:campsite_signup][:checkout_date] = open_campsite.checkout_date.to_s

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(open_campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "You are confirmed for this campsite.", flash[:notice]
    signup.reload
    assert signup.confirmed?
    assert_equal open_campsite, signup.campsite
    assert_equal open_campsite.arrival_date, signup.arrival_date
    assert_equal open_campsite.checkout_date, signup.checkout_date
    assert_not signup.waitlist_eligible?
    assert signup.waiver_signed?
    assert_empty trips(:yosemite).waitlisted_signups.where(user: users(:sam))
  end

  test "waitlisted user with linked party sees party confirmation note for open campsite" do
    full_campsite = campsites(:yosemite_a)
    open_campsite = campsites(:yosemite_b)
    fill_campsite_capacity(full_campsite, "waitlisted-party-open-campsite", count: full_campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    post signup_url_for(full_campsite), params: waiver_signature_params_with_guests(
      { first_name: "Gina", last_name: "Guest", email: "waitlisted-party-note@example.com", phone: "" }
    )
    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.includes_guests?

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{open_campsite.id}" do
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
      assert_select ".signup-modal-title-line", text: /This will remove you from the waitlist/, count: 0
    end
  end

  test "eligible waitlisted party sees confirm spot for open campsite" do
    campsite = campsites(:yosemite_a)
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "eligible-open-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    create_waitlisted_signup!(
      trip: trips(:yosemite),
      user: guest_user,
      guest_of_signup: signup,
      guest_position: 1
    )
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".spot-open-message", text: "A spot has opened up!"
      assert_select "button", text: "Confirm your spot"
      assert_select "button", text: "Signup for campsite", count: 0
      assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='confirm_waitlist']"
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "td", text: "Yes"
      assert_select ".waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
    end
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
    assert_nil signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_equal 5, campsite.reload.confirmed_signup_count
  end

  test "participant and guests are waitlisted together when capacity cannot fit party" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "guest-party-waitlist", count: campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 2 do
      post signup_url_for, params: waiver_signature_params_with_guests(
        { first_name: "Gina", last_name: "Guest", email: "waitlist-party-guest@example.com", phone: "" }
      )
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    guest_signup = signup.guest_signups.first
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_not signup.waiver_signed?
    assert guest_signup.waitlisted?
    assert_nil guest_signup.campsite
    assert_equal 5, campsite.reload.confirmed_signup_count

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".trip-waitlist-section tbody tr", count: 1
    assert_select ".trip-waitlist-section tbody tr", text: /Sam L\. \+ Gina G\./
    assert_select ".trip-waitlist-section", text: /Gina Guest/, count: 0
  end

  test "locked campsite with open space keeps direct signup closed" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.zone.local(2026, 5, 1, 10))
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: waiver_signature_params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "This campsite is using the waitlist.", flash[:alert]

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".campsite-card-header > div:not(.campsite-signup-action) > .campsite-lock-notice", count: 0
      assert_select ".campsite-signup-action .campsite-lock-notice", text: /Spots filled on 5\/2026\.\s+Waitlisted sign ups only/
      assert_select "button", text: "Join waitlist"
    end
  end

  test "eligible waitlisted participant can confirm an open locked campsite spot" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.current)
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".spot-open-message", text: "A spot has opened up!"
      assert_select "button", text: "Confirm your spot"
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move you from the waitlist to confirmed"
      assert_select "form[action='#{signup_path_for(campsite)}'][method='post']", text: /Pay Now and Confirm/
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "td", text: "Yes"
      assert_select "button", text: "Signup"
      assert_select ".waitlist-transition-note", text: "This will move you from the waitlist to confirmed"
      assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='confirm_waitlist']"
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "confirm_waitlist"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: params
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal campsite, signup.campsite
    assert_equal campsite.arrival_date, signup.arrival_date
    assert_equal campsite.checkout_date, signup.checkout_date
    assert signup.waiver_signed?
  end

  test "eligible waitlisted participant confirms linked guests into same campsite and dates" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.current)
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "confirm-linked-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_waitlisted_signup!(
      trip: trips(:yosemite),
      user: guest_user,
      guest_of_signup: signup,
      guest_position: 1
    )
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select ".waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "confirm_waitlist"
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    signup.reload
    guest_signup.reload
    assert signup.confirmed?
    assert_not signup.waitlist_eligible?
    assert guest_signup.confirmed?
    assert_equal campsite, guest_signup.campsite
    assert_equal Date.new(2026, 6, 13), guest_signup.arrival_date
    assert_equal Date.new(2026, 6, 15), guest_signup.checkout_date
    assert_not guest_signup.waiver_signed?
  end

  test "eligible waitlisted participant can choose between open locked campsites" do
    first_campsite = campsites(:yosemite_a)
    second_campsite = campsites(:yosemite_b)
    first_campsite.update!(signups_locked_at: Time.current)
    second_campsite.update!(signups_locked_at: Time.current)
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "button", text: "Signup"
      assert_select ".campsite-choice-options[data-campsite-choice-target='chooser'] legend", text: "Choose campsite"
      assert_select ".campsite-choice-option", text: /site A12/
      assert_select ".campsite-choice-option", text: /site A13/
      assert_select ".campsite-choice-option input[type='radio'][checked]", count: 0
      assert_select ".campsite-choice-panel[hidden]", count: 2
      assert_select ".campsite-choice-summary button", text: "Change campsite"
      assert_select "form[action='#{signup_path_for(first_campsite)}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='confirm_waitlist']"
      end
      assert_select "form[action='#{signup_path_for(second_campsite)}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='confirm_waitlist']"
      end
    end
  end

  test "ineligible waitlisted participant does not see confirm action for open locked campsite spot" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.current)
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".spot-open-message", count: 0
      assert_select "button", text: "Confirm your spot", count: 0
      assert_select "button[disabled]", text: "On waitlist"
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "td", text: "No"
      assert_select "button", text: "Signup", count: 0
    end
  end

  test "waitlist confirmation fails if capacity disappears" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "confirm-race")
    campsite.lock_signups!
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    log_in_as(users(:sam))

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "confirm_waitlist"

    post signup_url_for(campsite), params: params

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "That campsite spot is no longer available.", flash[:alert]
    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_nil signup.campsite
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

  test "public confirmed participants table abbreviates names and hides contact details" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: Date.new(2026, 6, 13))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select ".participant-list", count: 0
      assert_select "table.confirmed-participants-table"
      assert_equal [ "Participant", "Member", "Dates", "Minors" ], css_select(".confirmed-participants-table th").map { |header| header.text.strip }
      assert_select ".confirmed-participants-table tbody tr", count: 1
      assert_select ".confirmed-participants-table tbody tr" do
        assert_select "td", text: "Sam L."
        assert_select "td", text: "Non-member"
        assert_select "td", text: "Jun 13-Jun 15"
        assert_select "td", text: "None"
      end
      assert_select ".confirmed-participants-table", text: /Sam Lee/, count: 0
      assert_select ".confirmed-participants-table", text: /555-0101/, count: 0
      assert_select ".confirmed-participants-table", text: /sam@example.com/, count: 0
    end
  end

  test "public confirmed participants table summarizes minors without names" do
    SiteSetting.current.update!(uncounted_minor_age_limit: 10)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 9, relationship: "Child")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table tbody tr" do
      assert_select "td", text: "Sam L."
      assert_select "td", text: "Jun 12-Jun 15"
      assert_select "td", text: "1 under 10yrs"
    end
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Mika/, count: 0
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /1 minor/, count: 0
  end

  test "public confirmed participants table separates minor age categories" do
    SiteSetting.current.update!(uncounted_minor_age_limit: 10)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 9, relationship: "Child")
    signup.campsite_signup_minors.create!(first_name: "Teen", last_name: "Lee", age: 12, relationship: "Child")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table tbody tr" do
      assert_select "td", text: "1 under 10yrs and 1 over 10yrs"
    end
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Mika/, count: 0
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Teen/, count: 0
  end

  test "public confirmed participants table shows guest rows with added by and membership" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:alex))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "public-confirmed-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD
    )
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1,
      arrival_date: primary_signup.arrival_date,
      checkout_date: primary_signup.checkout_date
    )

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select ".confirmed-participants-table tbody tr", count: 2
      assert_select ".confirmed-participants-table tbody tr:first-child" do
        assert_select "td", text: "Alex R."
        assert_select "td", text: "Member"
        assert_select ".public-added-by", count: 0
      end
      assert_select ".confirmed-participants-table tbody tr:last-child" do
        assert_select "td", text: /Gina G\./
        assert_select "td", text: "Non-member"
        assert_select ".public-added-by", text: "Added by Alex R."
      end
      assert_select ".confirmed-participants-table", text: /Alex Rivera/, count: 0
      assert_select ".confirmed-participants-table", text: /Gina Guest/, count: 0
      assert_select ".confirmed-participants-table", text: /public-confirmed-guest@example.com/, count: 0
    end
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
    waitlisted_user = User.create!(first_name: "Willa", last_name: "Wait", email: "willa@example.com", password: "password")
    willa_joined_at = Time.zone.local(2026, 5, 2, 9, 15)
    alex_joined_at = Time.zone.local(2026, 5, 3, 16, 45)
    campsites(:yosemite_a).lock_signups!
    create_waitlisted_signup!(trip: trip, user: waitlisted_user, created_at: willa_joined_at)
    create_waitlisted_signup!(trip: trip, user: users(:alex), created_at: alex_joined_at, waitlist_eligible_at: Time.current)

    get trip_url(trip)

    assert_response :success
    assert_select ".trip-waitlist-section", text: /Trip waitlist/
    assert_select ".trip-waitlist-note", text: "Waitlist priority goes to club members"
    assert_select ".trip-waitlist-section table.waitlist-table"
    waitlist_headers = css_select(".trip-waitlist-section th").map { |header| header.text.strip }
    assert_equal [ "Priority", "Participant", "Member", "Joined Waitlist", "Able to signup", "", "" ], waitlist_headers
    assert_select ".trip-waitlist-section tbody tr:first-child" do
      assert_select "td", text: "1"
      assert_select "td", text: "Alex R."
      assert_select "td", text: "Member"
      assert_select "td", text: alex_joined_at.strftime("%B %-d, %Y %-l:%M %p")
      assert_select "td", text: "Yes"
      assert_select "button", text: "Signup", count: 0
    end
    assert_select ".trip-waitlist-section tbody tr:last-child" do
      assert_select "td", text: "2"
      assert_select "td", text: "Willa W."
      assert_select "td", text: "Non-member"
      assert_select "td", text: willa_joined_at.strftime("%B %-d, %Y %-l:%M %p")
      assert_select "td", text: "No"
      assert_select "button", text: "Signup", count: 0
    end
    assert_select ".trip-waitlist-section .participant-list", count: 0
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
    params[:campsite_signup][:with_minors] = "1"
    params[:campsite_signup][:campsite_signup_minors_attributes] = minor_attributes.each_with_index.to_h do |attributes, index|
      [ index.to_s, attributes ]
    end
    params
  end

  def waiver_signature_params_with_guests(*guest_attributes)
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:with_guests] = "1"
    params[:campsite_signup][:guest_attributes] = guest_attributes.each_with_index.to_h do |attributes, index|
      [ index.to_s, attributes ]
    end
    params
  end

  def waiver_signature_params_with_minors_and_guests(minor_attributes, guest_attributes)
    params = waiver_signature_params_with_minors(*minor_attributes)
    params[:campsite_signup][:with_guests] = "1"
    params[:campsite_signup][:guest_attributes] = guest_attributes.each_with_index.to_h do |attributes, index|
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

  def waitlist_signup_params
    {
      campsite_signup: {
        intent: "join_waitlist",
        signup_kind: "self"
      }
    }
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
