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
end
