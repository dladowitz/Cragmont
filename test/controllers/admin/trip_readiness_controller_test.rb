require "test_helper"

class Admin::TripReadinessControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "admin can view trip readiness checklist" do
    trips(:yosemite).update!(
      whatsapp_group: "https://chat.whatsapp.com/yosemite-readiness",
      weather_url: "https://forecast.weather.gov/yosemite-readiness",
      photo_album_url: "https://photos.app.goo.gl/yosemite-readiness"
    )

    get readiness_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h2", "Trip Readiness"
    assert_select ".trip-readiness-category", count: 4
    assert_select "#readiness-trip", text: /Campsite Coordinator assigned/
    assert_select "#readiness-trip", text: /Create Google Photo Album/
    assert_select "#readiness-trip a.button.secondary[href='#{edit_admin_trip_path(trips(:yosemite))}']", text: "Add Coordinator"
    assert_select "#readiness-trip a.button.secondary[href='#{edit_admin_trip_path(trips(:yosemite))}']", text: "Add Group"
    assert_select "#readiness-trip a.button.secondary[href='#{edit_admin_trip_path(trips(:yosemite))}']", text: "Add Weather"
    assert_select "#readiness-trip a.button.secondary[href='#{edit_admin_trip_path(trips(:yosemite))}']", text: "Add Album"
    assert_select "#readiness-trip a[href='https://chat.whatsapp.com/yosemite-readiness'][target='_blank'][rel='noopener']", text: "link"
    assert_select "#readiness-trip a[href='https://forecast.weather.gov/yosemite-readiness'][target='_blank'][rel='noopener']", text: "link"
    assert_select "#readiness-trip a[href='https://photos.app.goo.gl/yosemite-readiness'][target='_blank'][rel='noopener']", text: "link"
    assert_select "#readiness-campsites", text: /Registered By/
    assert_select "#readiness-campsites", text: /Registration Number/
    assert_select "#readiness-campsites", text: /Registration Cost/
    assert_select "#readiness-campsites .trip-readiness-campsite-group", count: 2
    assert_select "#readiness-campsites .trip-readiness-campsite-title-row h3", text: "Upper Pines site A12"
    assert_select "#readiness-campsites .trip-readiness-campsite-title-row h3", text: "Upper Pines site A13"
    assert_select "#readiness-campsites .trip-readiness-campsite-title-row .trip-readiness-kind-status", text: "Auto Calculated", count: 2
    assert_select "#readiness-campsites a.button.secondary[href='#{edit_admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_a))}']", text: "Update Campsite"
    assert_select "#readiness-campsites a.button.secondary[href='#{edit_admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_b))}']", text: "Update Campsite"
    assert_select "#readiness-campsites a.button.secondary", text: /Add Registered By/, count: 0
    assert_select "#readiness-campsites .trip-readiness-campsite-check h4", text: "Registered By", count: 2
    assert_select "#readiness-campsites .trip-readiness-campsite-check h4", text: "Registration Number", count: 2
    assert_select "#readiness-campsites .trip-readiness-campsite-check h4", text: "Registration Cost", count: 2
    assert_select "#readiness-campsites form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "campsite_#{campsites(:yosemite_b).id}_registered_by")}']"
    assert_select "#readiness-campsites input.trip-readiness-small-button[type='submit'][value='Mark Complete']"
    assert_select "[data-readiness-count-key='overall']"
    assert_select "#readiness-campsites [data-readiness-task-key='campsite_#{campsites(:yosemite_b).id}_registered_by']"
    assert_select "form.trip-readiness-toggle-form[data-controller='readiness-toggle'][data-action='submit->readiness-toggle#submit'][data-turbo='false']"
    assert_select "#readiness-participant", text: /Send out trip details email with check-in info/
    assert_select "#readiness-participant", text: /campsite registration number/
    assert_select "#readiness-post_trip", text: /Send collected money to Treasurer/
  end

  test "manual tasks can be checked and unchecked" do
    assert_difference "TripReadinessCompletion.count", 1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), "send_trip_details_email"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task marked complete.", flash[:notice]
    completion = trips(:yosemite).trip_readiness_completions.find_by!(task_key: "send_trip_details_email")
    assert_equal users(:alex), completion.completed_by

    assert_difference "TripReadinessCompletion.count", -1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), "send_trip_details_email"), params: { completed: "0" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task moved back onto the rack.", flash[:notice]
  end

  test "selected automatic trip tasks can be manually overridden" do
    trips(:yosemite).update!(photo_album_url: nil)

    assert_difference "TripReadinessCompletion.count", 1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), "create_google_photo_album"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task marked complete.", flash[:notice]

    get readiness_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#readiness-trip", text: /Create Google Photo Album/
    assert_select "#readiness-trip", text: /Completed by Alex Rivera/
    assert_select "#readiness-trip form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "create_google_photo_album")}'] input[name='completed'][value='0']"
    assert_select "#readiness-trip input[type='submit'][value='Mark incomplete']"
  end

  test "non-overridable automatic tasks cannot be toggled" do
    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trips(:yosemite), "all_confirmed_participants_signed_waiver"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "Wow, that was a whipper. That readiness task cannot be changed.", flash[:alert]
  end

  test "campsite tasks can be manually overridden per campsite" do
    task_key = "campsite_#{campsites(:yosemite_b).id}_registration_number"

    assert_difference "TripReadinessCompletion.count", 1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), task_key), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task marked complete.", flash[:notice]

    get readiness_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#readiness-campsites .trip-readiness-campsite-title-row h3", text: "Upper Pines site A13"
    assert_select "#readiness-campsites .trip-readiness-campsite-check h4", text: "Registration Number"
    assert_select "#readiness-campsites form[action='#{readiness_task_admin_trip_path(trips(:yosemite), task_key)}'] input[name='completed'][value='0']"
    assert_select "#readiness-campsites input.trip-readiness-small-button[type='submit'][value='Mark incomplete']"
  end

  test "manual task update can respond with json for background updates" do
    patch readiness_task_admin_trip_url(trips(:yosemite), "send_trip_details_email"),
      params: { completed: "1" },
      headers: { "Accept" => "application/json" }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "On belay! Readiness task marked complete.", response_body.fetch("message")
    assert_equal "send_trip_details_email", response_body.dig("task", "key")
    assert_equal true, response_body.dig("task", "complete")
    assert_equal "0", response_body.dig("task", "completed_value")
    assert_equal "Mark incomplete", response_body.dig("task", "button_text")
    assert_match(/Completed by Alex Rivera on/, response_body.dig("task", "completion_text"))
    assert_equal "participant", response_body.dig("category", "key")
    assert_match(/\A\d+ of \d+\z/, response_body.dig("total", "count_text"))

    patch readiness_task_admin_trip_url(trips(:yosemite), "send_trip_details_email"),
      params: { completed: "0" },
      headers: { "Accept" => "application/json" }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal false, response_body.dig("task", "complete")
    assert_equal "1", response_body.dig("task", "completed_value")
    assert_equal "Mark Complete", response_body.dig("task", "button_text")
    assert_nil response_body.dig("task", "completion_text")
  end

  test "finance admin can view but not change manual tasks" do
    finance_user = users(:sam)
    assign_role(finance_user, :finance_admin)
    delete session_url
    log_in_as(finance_user)

    get readiness_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".trip-readiness-task-actions", text: /Read only/

    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trips(:yosemite), "send_trip_details_email"), params: { completed: "1" }
    end

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end

  test "deleted trips are read only" do
    trip = trips(:jtree)
    trip.soft_delete!

    get readiness_admin_trip_url(trip)

    assert_response :success
    assert_select ".deleted-trip-banner", text: /Restore the trip/
    assert_select ".trip-readiness-task-actions", text: /Read only/

    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trip, "send_trip_details_email"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trip)
    assert_equal "Wow, that was a whipper. Restore this trip before changing readiness tasks.", flash[:alert]
  end

  test "assigned campsite coordinator can view and update their trip readiness" do
    coordinator = users(:sam)
    trips(:jtree).update!(campsite_coordinator: coordinator)
    delete session_url
    log_in_as(coordinator)

    get readiness_admin_trip_url(trips(:jtree))

    assert_response :success

    assert_difference "TripReadinessCompletion.count", 1 do
      patch readiness_task_admin_trip_url(trips(:jtree), "send_photo_upload_reminder"), params: { completed: "1" }
    end
  end
end
