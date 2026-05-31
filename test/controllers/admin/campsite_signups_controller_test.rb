require "test_helper"

class Admin::CampsiteSignupsControllerTest < ActionDispatch::IntegrationTest
  test "can mark waitlisted participant eligible" do
    participant = User.create!(
      first_name: "Willa",
      last_name: "Wait",
      email: "eligible-waitlist@example.com",
      password: "password"
    )
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: participant)

    patch make_waitlist_eligible_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert signup.reload.waitlist_eligible?
  end

  test "does not mark confirmed participant eligible" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    patch make_waitlist_eligible_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_not signup.reload.waitlist_eligible?
    assert_equal "Sam Lee is already confirmed for this trip.", flash[:alert]
  end

  test "can revoke waitlisted participant signup ability" do
    participant = User.create!(
      first_name: "Willa",
      last_name: "Wait",
      email: "revoke-waitlist@example.com",
      password: "password"
    )
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: participant, waitlist_eligible_at: Time.current)

    patch revoke_waitlist_eligibility_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_not signup.reload.waitlist_eligible?
    assert_equal "Willa Wait can no longer confirm an open campsite spot.", flash[:notice]
  end

  test "can move waitlisted participant to campsite over capacity" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    campsite.participant_capacity.times do |index|
      create_campsite_signup!(
        campsite: campsite,
        user: User.create!(
          first_name: "Full",
          last_name: "Participant#{index}",
          email: "full-participant-#{index}@example.com",
          password: "password"
        )
      )
    end
    participant = User.create!(
      first_name: "Morgan",
      last_name: "Waitlist",
      email: "morgan-waitlist@example.com",
      password: "password"
    )
    signup = create_waitlisted_signup!(trip: trip, user: participant, waitlist_eligible_at: Time.current)

    patch move_to_campsite_admin_trip_campsite_signup_url(trip, signup), params: {
      campsite_signup: {
        campsite_id: campsite.id
      }
    }

    assert_redirected_to admin_trip_url(trip)
    assert_equal "Morgan Waitlist was moved to Upper Pines site A12.", flash[:notice]
    signup.reload
    assert signup.confirmed?
    assert_equal campsite, signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_equal "Not chosen yet", signup.attendance_date_range
    assert_not signup.waitlist_eligible?
    assert campsite.reload.signups_locked?
    assert_equal campsite.participant_capacity + 1, campsite.confirmed_signup_count
  end

  test "does not move confirmed participant to campsite" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    patch move_to_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
      campsite_signup: {
        campsite_id: campsites(:yosemite_b).id
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee is already confirmed for this trip.", flash[:alert]
    assert_equal campsites(:yosemite_a), signup.reload.campsite
  end

  test "can move confirmed participant to waitlist" do
    campsite = campsites(:yosemite_a)
    campsite.update!(participant_capacity: 1)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam), waitlist_eligible_at: Time.current)

    patch move_to_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee was moved to the waitlist.", flash[:notice]
    signup.reload
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_not signup.waitlist_eligible?
    assert campsite.reload.signups_locked?
  end

  test "does not move waitlisted participant to waitlist" do
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))

    patch move_to_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee is already on the waitlist.", flash[:alert]
    assert signup.reload.waitlisted?
  end

  test "can remove confirmed participant from campsite and advance waitlist" do
    campsite = campsites(:yosemite_a)
    campsite.update!(participant_capacity: 1)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam))
    waitlisted_user = User.create!(
      first_name: "Waiting",
      last_name: "Participant",
      email: "waiting-participant@example.com",
      password: "password"
    )
    waitlisted_signup = create_waitlisted_signup!(trip: trips(:yosemite), user: waitlisted_user)

    assert_difference "CampsiteSignup.count", -1 do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee was removed from Upper Pines site A12.", flash[:notice]
    assert campsite.reload.signups_locked?
    assert waitlisted_signup.reload.waitlist_eligible?
  end

  test "does not remove waitlisted participant from campsite" do
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee is not confirmed for a campsite.", flash[:alert]
    assert signup.reload.waitlisted?
  end
end
