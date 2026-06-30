require "test_helper"

class Admin::TripPostTripControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "admin can view post trip checklist" do
    get post_trip_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h2", "Post Trip"
    assert_select ".trip-readiness-category", count: 1
    assert_select "#readiness-post_trip", text: /All campsites reimbursed/
    assert_select "#readiness-post_trip", text: /Send collected money to Treasurer/
    assert_select "#readiness-post_trip", text: /Send reminder to participants to upload photos to album/
    assert_select "#readiness-post_trip input.trip-readiness-small-button[type='submit'][value='Manually Mark']"
    assert_select "form.trip-readiness-toggle-form[data-controller='readiness-toggle'][data-action='submit->readiness-toggle#submit'][data-turbo='false']"
    assert_select "form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "all_campsites_reimbursed")}'] input[name='scope'][value='post_trip']"
    assert_select "form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "send_collected_money_to_treasurer")}'] input[name='scope'][value='post_trip']"
  end

  test "day trip post trip checklist hides camping-only money tasks" do
    trip = create_day_trip!

    get post_trip_admin_trip_url(trip)

    assert_response :success
    assert_select "h2", "Post Trip"
    assert_select ".trip-readiness-category", count: 1
    assert_select "#readiness-post_trip", text: /Send reminder to participants to upload photos to album/
    assert_select "#readiness-post_trip", text: /All campsites reimbursed/, count: 0
    assert_select "#readiness-post_trip", text: /Send collected money to Treasurer/, count: 0
    assert_select "form[action='#{readiness_task_admin_trip_path(trip, "send_photo_upload_reminder")}'] input[name='scope'][value='post_trip']"
    assert_select "form[action='#{readiness_task_admin_trip_path(trip, "all_campsites_reimbursed")}']", count: 0
    assert_select "form[action='#{readiness_task_admin_trip_path(trip, "send_collected_money_to_treasurer")}']", count: 0
  end

  test "admin cannot complete hidden day trip post trip money tasks" do
    trip = create_day_trip!

    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trip, "send_collected_money_to_treasurer"),
        params: { completed: "1", scope: "post_trip" }
    end

    assert_redirected_to post_trip_admin_trip_url(trip)
    assert_equal "Wow, that was a whipper. That readiness task cannot be changed.", flash[:alert]
  end

  test "post trip tasks redirect back to post trip page after html update" do
    assert_difference "TripReadinessCompletion.count", 1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), "send_collected_money_to_treasurer"),
        params: { completed: "1", scope: "post_trip" }
    end

    assert_redirected_to post_trip_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task marked complete.", flash[:notice]
  end

  test "finance admin can view post trip but not change tasks" do
    finance_user = users(:sam)
    assign_role(finance_user, :finance_admin)
    delete session_url
    log_in_as(finance_user)

    get post_trip_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".trip-readiness-task-actions", text: /Read only/

    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trips(:yosemite), "send_collected_money_to_treasurer"),
        params: { completed: "1", scope: "post_trip" }
    end

    assert_redirected_to root_url
  end

  private

  def create_day_trip!
    Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Post Trip",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 12),
      description: "Single day cragging.",
      status: "published",
      meeting_time: "08:30",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, hike toward the main wall.",
      participant_capacity: 8,
      climbing_types: [ "sport" ]
    )
  end
end
