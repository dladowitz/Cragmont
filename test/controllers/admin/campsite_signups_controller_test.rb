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
end
