require "test_helper"

class Admin::TripReadinessControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "admin can view trip readiness checklist" do
    trips(:yosemite).update!(
      whatsapp_group: "https://chat.whatsapp.com/yosemite-readiness",
      weather_url: "https://forecast.weather.gov/yosemite-readiness",
      mountain_project_url: "https://www.mountainproject.com/area/yosemite-readiness",
      guide_book_url: "https://example.com/yosemite-guide",
      sun_exposure: "Morning shade",
      photo_album_url: "https://photos.app.goo.gl/yosemite-readiness"
    )

    get readiness_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h2", "Trip Readiness"
    assert_select ".trip-readiness-overview .trip-readiness-category-title-row" do
      assert_select "h2", "Trip Readiness"
      assert_select "[data-readiness-count-key='overall']", text: /\A\d+ of \d+\z/
    end
    assert_select ".trip-readiness-category", count: 3
    assert_select "#readiness-trip", text: /Trip Coordinator assigned/
    assert_select "#readiness-trip", text: /Mountain Project link added/
    assert_select "#readiness-trip", text: /Guide Book link added/
    assert_select "#readiness-trip", text: /Sun Exposure added/
    assert_select "#readiness-trip", text: /Create Google Photo Album/
    assert_select "#readiness-trip", text: /Group campfire site and night set/
    assert_select "#readiness-trip [data-readiness-task-key='add_photo_album_to_older_website'] .trip-readiness-task-subtext a[href='https://www.cragmontclimbingclub.org/past-trips'][target='_blank'][rel='noopener']",
      text: "https://www.cragmontclimbingclub.org/past-trips"
    assert_select "#readiness-trip .trip-readiness-trip-group", count: 1
    assert_select "#readiness-trip .trip-readiness-campsite-title-row h3", text: "Yosemite Valley Spring", count: 0
    assert_select "#readiness-trip .trip-readiness-category-title-row.has-trip-heading" do
      assert_select "h2", text: "Trip"
      assert_select ".trip-readiness-trip-heading", text: /Yosemite Valley Spring/
      assert_select ".trip-readiness-trip-date", text: /6\/12\/2026 to 6\/15\/2026/
      assert_select "[data-readiness-count-key='trip']", text: /\A\d+ of \d+\z/
    end
    assert_select ".trip-readiness-overview .muted", text: /June 12, 2026/, count: 0
    assert_select "#readiness-trip a.button.secondary[href='#{edit_admin_trip_path(trips(:yosemite))}']", text: "Update Trip", count: 1
    assert_select "#readiness-trip a.button.secondary", text: /Add Coordinator/, count: 0
    assert_select "#readiness-trip a.button.secondary", text: /Add Group/, count: 0
    assert_select "#readiness-trip a.button.secondary", text: /Add Weather/, count: 0
    assert_select "#readiness-trip a.button.secondary", text: /Add Album/, count: 0
    assert_select "#readiness-trip form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "group_campfire_planned")}']"
    assert_select "#readiness-trip input.trip-readiness-small-button[type='submit'][value='Manually Mark']"
    assert_select "#readiness-trip [data-readiness-task-key='campsite_coordinator_assigned'] .trip-readiness-auto-badge", text: "auto calc"
    assert_select "#readiness-trip [data-readiness-task-key='whatsapp_group_created'] .trip-readiness-auto-badge", text: "auto calc"
    assert_select "#readiness-trip [data-readiness-task-key='weather_link_added'] .trip-readiness-auto-badge", text: "auto calc"
    assert_select "#readiness-trip [data-readiness-task-key='mountain_project_link_added'] .trip-readiness-auto-badge", text: "auto calc"
    assert_select "#readiness-trip [data-readiness-task-key='guide_book_link_added'] .trip-readiness-auto-badge", text: "auto calc"
    assert_select "#readiness-trip [data-readiness-task-key='sun_exposure_added'] .trip-readiness-auto-badge", text: "auto calc"
    assert_select "#readiness-trip [data-readiness-task-key='sun_exposure_added'] .trip-readiness-task-subtext",
      text: "Morning shade"
    assert_select "#readiness-trip [data-readiness-task-key='add_photo_album_to_older_website'] .trip-readiness-auto-badge", count: 0
    assert_select "#readiness-trip [data-readiness-task-key='whatsapp_group_created'] .trip-readiness-task-subtext a[href='https://chat.whatsapp.com/yosemite-readiness'][target='_blank'][rel='noopener']", text: "Link"
    assert_select "#readiness-trip [data-readiness-task-key='weather_link_added'] .trip-readiness-task-subtext a[href='https://forecast.weather.gov/yosemite-readiness'][target='_blank'][rel='noopener']", text: "Link"
    assert_select "#readiness-trip [data-readiness-task-key='mountain_project_link_added'] .trip-readiness-task-subtext a[href='https://www.mountainproject.com/area/yosemite-readiness'][target='_blank'][rel='noopener']", text: "Link"
    assert_select "#readiness-trip [data-readiness-task-key='guide_book_link_added'] .trip-readiness-task-subtext a[href='https://example.com/yosemite-guide'][target='_blank'][rel='noopener']", text: "Link"
    assert_select "#readiness-trip [data-readiness-task-key='create_google_photo_album'] .trip-readiness-task-subtext a[href='https://photos.app.goo.gl/yosemite-readiness'][target='_blank'][rel='noopener']", text: "Link"
    assert_select "#readiness-campsites", text: /Registered By/
    assert_select "#readiness-campsites", text: /Registration Number/
    assert_select "#readiness-campsites", text: /Registration Cost/
    assert_select "#readiness-campsites .trip-readiness-campsite-group", count: 2
    assert_select "#readiness-campsites .trip-readiness-campsite-title-row h3", text: "Upper Pines site A12"
    assert_select "#readiness-campsites .trip-readiness-campsite-title-row h3", text: "Upper Pines site A13"
    assert_select ".trip-readiness-kind-status", count: 0
    assert_select ".trip-readiness-category", text: /Auto Calculated/, count: 0
    assert_select ".trip-readiness-category", text: /Manually Completed/, count: 0
    assert_select "#readiness-campsites a.button.secondary[href='#{edit_admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_a))}']", text: "Update Campsite"
    assert_select "#readiness-campsites a.button.secondary[href='#{edit_admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_b))}']", text: "Update Campsite"
    assert_select "#readiness-campsites a.button.secondary", text: /Add Registered By/, count: 0
    assert_select "#readiness-campsites .trip-readiness-campsite-check h4", text: "Registered By", count: 2
    assert_select "#readiness-campsites .trip-readiness-campsite-check h4", text: "Registration Number", count: 2
    assert_select "#readiness-campsites .trip-readiness-campsite-check h4", text: "Registration Cost", count: 2
    assert_select "#readiness-campsites form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "campsite_#{campsites(:yosemite_b).id}_registered_by")}']"
    assert_select "#readiness-campsites input.trip-readiness-small-button[type='submit'][value='Manually Mark']"
    assert_select "#readiness-campsites [data-readiness-task-key='campsite_#{campsites(:yosemite_a).id}_registered_by'] .trip-readiness-auto-badge", text: "auto calc"
    assert_select "[data-readiness-count-key='overall']"
    assert_select "#readiness-campsites [data-readiness-task-key='campsite_#{campsites(:yosemite_b).id}_registered_by']"
    assert_select "form.trip-readiness-toggle-form[data-controller='readiness-toggle'][data-action='submit->readiness-toggle#submit'][data-turbo='false']"
    assert_select "#readiness-participant", text: /Send out trip details email with check-in info/
    assert_select "#readiness-participant h2", text: "Participants"
    assert_select "#readiness-participant", text: /All waivers signed/
    assert_select "#readiness-participant", text: /All fees paid or waived/
    assert_select "#readiness-participant", text: /Parking assigned/
    assert_select "#readiness-participant", text: /Send out redacted photo ids/
    assert_select "#readiness-participant", text: /All confirmed participants signed waiver/, count: 0
    assert_select "#readiness-participant", text: /All confirmed primary participants paid or have fees waived/, count: 0
    assert_select "#readiness-participant", text: /All confirmed participants assigned parking/, count: 0
    assert_select "#readiness-participant form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "all_confirmed_participants_signed_waiver")}']"
    assert_select "#readiness-participant form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "all_confirmed_participants_assigned_parking")}']"
    assert_select "#readiness-participant form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "send_redacted_photo_ids")}']"
    assert_select "#readiness-participant input.trip-readiness-small-button[type='submit'][value='Manually Mark']"
    assert_select "#readiness-participant [data-readiness-task-key='send_trip_details_email'] .trip-readiness-task-subtext",
      text: "Create, preview, and send the trip details email before heading out."
    assert_select "#readiness-participant form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "send_trip_details_email")}']", count: 0
    assert_select "#readiness-participant", text: /campsite registration number/, count: 0
    assert_select "#readiness-post_trip", count: 0
    assert_select ".trip-readiness-category", text: /Send collected money to Treasurer/, count: 0
  end

  test "admin day trip readiness checklist hides campfire campsites and participants" do
    trip = create_day_trip!

    get readiness_admin_trip_url(trip)

    assert_response :success
    assert_select "h2", "Trip Readiness"
    assert_select ".trip-readiness-overview", count: 0
    assert_select ".trip-readiness-category", count: 1
    assert_select "#readiness-trip > .trip-readiness-category-header" do
      assert_select "h2", "Trip Readiness"
      assert_select "[data-readiness-count-key='trip']", text: /\A\d+ of \d+\z/
      assert_select ".trip-readiness-trip-heading", text: /#{trip.name}/
      assert_select ".trip-readiness-trip-date", text: /#{trip.start_date.strftime("%-m\/%-d\/%Y")}/
      assert_select "a[href='#{edit_admin_trip_path(trip)}']", text: "Update Trip"
      assert_select "a[href='#{admin_trip_path(trip)}']", text: "Back to trip"
    end
    assert_select "#readiness-trip", text: /Trip Coordinator assigned/
    assert_select "#readiness-trip", text: /WhatsApp Group created and added to trip/
    assert_select "#readiness-trip", text: /Mountain Project link added/
    assert_select "#readiness-trip", text: /Guide Book link added/
    assert_select "#readiness-trip", text: /Sun Exposure added/
    assert_select "#readiness-trip", text: /Create Google Photo Album/
    assert_select "#readiness-trip", text: /Verify there are enough lead climbers present/
    assert_select "#readiness-trip [data-readiness-task-key='verify_enough_lead_climbers'] .trip-readiness-task-subtext",
      text: "Generally want at least a 1:5 ratio to get ropes up"
    assert_select "form[action='#{readiness_task_admin_trip_path(trip, "verify_enough_lead_climbers")}']"
    assert_select "#readiness-trip", text: /Group campfire site and night set/, count: 0
    assert_select "#readiness-campsites", count: 0
    assert_select "#readiness-participant", count: 0
    assert_select ".trip-readiness-category", text: /All waivers signed/, count: 0
    assert_select ".trip-readiness-category", text: /All fees paid or waived/, count: 0
    assert_select ".trip-readiness-category", text: /Send out redacted photo ids/, count: 0
    assert_select "form[action='#{readiness_task_admin_trip_path(trip, "group_campfire_planned")}']", count: 0
  end

  test "admin day trip readiness hides lead climber check for bouldering only trips" do
    trip = create_day_trip!
    trip.update!(climbing_types: [ "bouldering" ])

    get readiness_admin_trip_url(trip)

    assert_response :success
    assert_select "#readiness-trip", text: /Verify there are enough lead climbers present/, count: 0
    assert_select "form[action='#{readiness_task_admin_trip_path(trip, "verify_enough_lead_climbers")}']", count: 0
  end

  test "admin cannot complete hidden day trip readiness tasks" do
    trip = create_day_trip!

    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trip, "group_campfire_planned"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trip)
    assert_equal "Wow, that was a whipper. That readiness task cannot be changed.", flash[:alert]
  end

  test "admin cannot complete hidden lead climber task for bouldering only trips" do
    trip = create_day_trip!
    trip.update!(climbing_types: [ "bouldering" ])

    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trip, "verify_enough_lead_climbers"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trip)
    assert_equal "Wow, that was a whipper. That readiness task cannot be changed.", flash[:alert]
  end

  test "manual tasks can be checked and unchecked" do
    assert_difference "TripReadinessCompletion.count", 1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), "add_photo_album_to_older_website"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task marked complete.", flash[:notice]
    completion = trips(:yosemite).trip_readiness_completions.find_by!(task_key: "add_photo_album_to_older_website")
    assert_equal users(:alex), completion.completed_by

    assert_difference "TripReadinessCompletion.count", -1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), "add_photo_album_to_older_website"), params: { completed: "0" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task moved back onto the rack.", flash[:notice]
  end

  test "photo album readiness cannot be manually overridden" do
    trips(:yosemite).update!(photo_album_url: nil)

    assert_no_difference "TripReadinessCompletion.count" do
      patch readiness_task_admin_trip_url(trips(:yosemite), "create_google_photo_album"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "Wow, that was a whipper. That readiness task cannot be changed.", flash[:alert]

    get readiness_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#readiness-trip", text: /Create Google Photo Album/
    assert_select "#readiness-trip", text: /Completed by Alex Rivera/, count: 0
    assert_select "#readiness-trip form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "create_google_photo_album")}']", count: 0
    assert_select "#readiness-trip [data-readiness-task-key='create_google_photo_album'] .trip-readiness-auto-badge", count: 0
  end

  test "participant automatic tasks can be manually overridden" do
    assert_difference "TripReadinessCompletion.count", 1 do
      patch readiness_task_admin_trip_url(trips(:yosemite), "all_confirmed_participants_signed_waiver"), params: { completed: "1" }
    end

    assert_redirected_to readiness_admin_trip_url(trips(:yosemite))
    assert_equal "On belay! Readiness task marked complete.", flash[:notice]

    get readiness_admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#readiness-participant form[action='#{readiness_task_admin_trip_path(trips(:yosemite), "all_confirmed_participants_signed_waiver")}'] input[name='completed'][value='0']"
    assert_select "#readiness-participant input.trip-readiness-small-button[type='submit'][value='Mark incomplete']"
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
    patch readiness_task_admin_trip_url(trips(:yosemite), "add_photo_album_to_older_website"),
      params: { completed: "1" },
      headers: { "Accept" => "application/json" }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "On belay! Readiness task marked complete.", response_body.fetch("message")
    assert_equal "add_photo_album_to_older_website", response_body.dig("task", "key")
    assert_equal true, response_body.dig("task", "complete")
    assert_equal "0", response_body.dig("task", "completed_value")
    assert_equal "Mark incomplete", response_body.dig("task", "button_text")
    assert_not response_body.fetch("task").key?("completion_text")
    assert_equal "trip", response_body.dig("category", "key")
    assert_match(/\A\d+ of \d+\z/, response_body.dig("total", "count_text"))

    patch readiness_task_admin_trip_url(trips(:yosemite), "add_photo_album_to_older_website"),
      params: { completed: "0" },
      headers: { "Accept" => "application/json" }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal false, response_body.dig("task", "complete")
    assert_equal "1", response_body.dig("task", "completed_value")
    assert_equal "Manually Mark", response_body.dig("task", "button_text")
    assert_not response_body.fetch("task").key?("completion_text")
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
      patch readiness_task_admin_trip_url(trips(:yosemite), "add_photo_album_to_older_website"), params: { completed: "1" }
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
      patch readiness_task_admin_trip_url(trip, "add_photo_album_to_older_website"), params: { completed: "1" }
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

  private

  def create_day_trip!
    Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Readiness",
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
