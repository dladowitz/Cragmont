require "test_helper"

class MemberPrioritySignupsTest < ActionDispatch::IntegrationTest
  setup do
    @trip = trips(:yosemite)
    @trip.update!(first_published_at: Time.current, members_only_until: 15.days.from_now.change(usec: 0))
    @campsite = campsites(:yosemite_a)
    @url = trip_campsite_campsite_signup_url(@trip, @campsite)
  end

  test "non members cannot bypass priority through direct or waitlist posts" do
    log_in_as(users(:sam))
    %w[direct_signup join_waitlist complete_participant_details].each do |intent|
      assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupPayment.count", "Waiver.count" ] do
        post @url, params: { campsite_signup: { intent: intent } }
      end
      assert_redirected_to trip_path(@trip)
      assert_includes flash[:alert], "Members get first dibs!"
    end
  end

  test "members can sign up during priority and non members can at the exact opening" do
    log_in_as(users(:alex))
    assert_difference "CampsiteSignup.count", 1 do
      post @url, params: waiver_signature_params
    end
    assert users(:alex).campsite_signups.last.confirmed?
    log_in_as(users(:sam))
    travel_to @trip.members_only_until do
      assert_difference "CampsiteSignup.count", 1 do
        post @url, params: waiver_signature_params
      end
    end
    assert users(:sam).campsite_signups.last.confirmed?
  end

  test "non member waitlist confirmations are blocked but withdrawal remains possible" do
    signup = create_waitlisted_signup!(trip: @trip, user: users(:sam), waitlist_eligible_at: Time.current)
    log_in_as(users(:sam))
    %w[confirm_waitlist waitlist_direct_signup].each do |intent|
      post @url, params: waiver_signature_params.deep_merge(campsite_signup: { intent: intent })
      assert_includes flash[:alert], "Members get first dibs!"
      assert signup.reload.waitlisted?
    end
    delete @url
    assert_redirected_to trip_path(@trip)
    assert_not @trip.campsite_signups.active.exists?(user: users(:sam))
  end

  test "existing confirmed non members keep participant details access" do
    signup = create_campsite_signup!(campsite: @campsite, user: users(:sam))
    log_in_as(users(:sam))
    post @url, params: waiver_signature_params.deep_merge(campsite_signup: { intent: "complete_participant_details" })
    assert_redirected_to trip_path(@trip)
    assert_not_includes flash[:alert].to_s, "Members get first dibs!"
    assert signup.reload.confirmed?
  end

  test "trip stays visible and explains eligibility without offering blocked forms" do
    get trips_url
    assert_select ".trip-card[href='#{trip_path(@trip)}'] .status", text: "Members first"
    get trip_url(@trip)
    assert_select ".member-priority-notice", text: /Non-member signup and waitlist access open/
    assert_select ".member-priority-notice a[href='#{membership_path}']"
    log_in_as(users(:sam))
    get trip_url(@trip)
    assert_select ".campsite-signup-action form", count: 0
    assert_select ".campsite-signup-action", text: /Member-only signup is open/, minimum: 1
    log_in_as(users(:alex))
    get trip_url(@trip)
    assert_select ".campsite-signup-action button", text: "Sign up for this campsite", minimum: 1
  end
end
