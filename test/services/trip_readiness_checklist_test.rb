require "test_helper"

class TripReadinessChecklistTest < ActiveSupport::TestCase
  test "marks trip setup tasks complete from existing trip data" do
    trip = trips(:yosemite)
    trip.update!(
      whatsapp_group: "https://chat.whatsapp.com/yosemite-readiness",
      weather_url: "https://forecast.weather.gov/yosemite-readiness",
      mountain_project_url: "https://www.mountainproject.com/area/yosemite-readiness",
      guide_book_url: "https://example.com/yosemite-guide",
      sun_exposure: "Morning shade",
      photo_album_url: "https://photos.app.goo.gl/yosemite-readiness",
      group_campfire_campsite: campsites(:yosemite_a),
      group_fire_night: "saturday"
    )

    tasks = tasks_by_key(trip)

    assert tasks.fetch("campsite_coordinator_assigned").complete?
    assert tasks.fetch("whatsapp_group_created").complete?
    assert tasks.fetch("weather_link_added").complete?
    assert tasks.fetch("guide_book_link_added").complete?
    assert tasks.fetch("create_google_photo_album").complete?
    assert tasks.fetch("group_campfire_planned").complete?
    assert_not_includes tasks.keys, "mountain_project_link_added"
    assert_not_includes tasks.keys, "sun_exposure_added"
    assert_equal "https://www.cragmontclimbingclub.org/past-trips", tasks.fetch("add_photo_album_to_older_website").detail
    assert_equal "Group campfire is planned at Upper Pines site A12 on Saturday.", tasks.fetch("group_campfire_planned").detail
  end

  test "trip setup group campfire task completes when no group campfire is planned" do
    trip = trips(:yosemite)
    trip.update!(group_campfire_campsite: nil, group_fire_night: "none")

    task = tasks_by_key(trip).fetch("group_campfire_planned")

    assert task.complete?
    assert_equal "No group campfire is planned.", task.detail
  end

  test "trip setup group campfire task requires a decision" do
    trip = trips(:yosemite)
    trip.update!(group_campfire_campsite: nil, group_fire_night: nil)

    task = tasks_by_key(trip).fetch("group_campfire_planned")

    assert task.automatic?
    assert task.overrideable?
    assert_not task.complete?
    assert_equal "Add Campfire", task.update_label
    assert_equal "Choose a group campfire site and night, or set the fire night to None if there will be no group campfire.", task.detail
  end

  test "rejects unsafe resource urls for automatic tasks" do
    trip = trips(:yosemite)
    trip.update!(
      whatsapp_group: "javascript:alert(1)",
      weather_url: "not a url",
      mountain_project_url: "javascript:alert(1)",
      guide_book_url: "ftp://example.com/guide",
      photo_album_url: "ftp://example.com/album"
    )

    tasks = tasks_by_key(trip)

    assert_not tasks.fetch("whatsapp_group_created").complete?
    assert_not tasks.fetch("weather_link_added").complete?
    assert_not tasks.fetch("guide_book_link_added").complete?
    assert_not tasks.fetch("create_google_photo_album").complete?
    assert_not_includes tasks.keys, "mountain_project_link_added"
  end

  test "photo album readiness only completes from the trip photo album url" do
    trip = trips(:yosemite)
    trip.update!(photo_album_url: nil)

    task = tasks_by_key(trip).fetch("create_google_photo_album")

    assert task.automatic?
    assert_not task.overrideable?
    assert_not task.complete?
    assert_not task.source_complete?
    assert_nil task.update_label
    assert_not TripReadinessChecklist.completable_task_key?("create_google_photo_album", trip: trip)
  end

  test "campsite checks are created for each campsite and required value" do
    trip = trips(:yosemite)
    campsites(:yosemite_a).update!(registration_fee: "84.25")
    campsites(:yosemite_b).update!(registration_fee: "92.50")

    tasks = tasks_by_key(trip)
    campsite_a_registered_by_key = "campsite_#{campsites(:yosemite_a).id}_registered_by"
    campsite_b_registered_by_key = "campsite_#{campsites(:yosemite_b).id}_registered_by"
    campsite_b_registration_number_key = "campsite_#{campsites(:yosemite_b).id}_registration_number"
    campsite_a_registration_cost_key = "campsite_#{campsites(:yosemite_a).id}_registration_cost"

    assert tasks.fetch(campsite_a_registered_by_key).complete?
    assert_not tasks.fetch(campsite_b_registered_by_key).complete?
    assert_not tasks.fetch(campsite_b_registration_number_key).complete?
    assert tasks.fetch(campsite_a_registration_cost_key).complete?
    assert_includes tasks.fetch(campsite_b_registered_by_key).name, "Upper Pines site A13"
    assert_includes tasks.fetch(campsite_b_registered_by_key).detail, "still needs a registrant"
    assert_includes tasks.fetch(campsite_b_registration_number_key).detail, "still needs a registration number"
    assert_equal "Add Registered By", tasks.fetch(campsite_b_registered_by_key).update_label
    assert_equal campsites(:yosemite_b), tasks.fetch(campsite_b_registered_by_key).update_campsite
    assert_equal "Add Registration Number", tasks.fetch(campsite_b_registration_number_key).update_label
    assert_equal campsites(:yosemite_b), tasks.fetch(campsite_b_registration_number_key).update_campsite
    assert_equal "Add Registration Cost", tasks.fetch(campsite_a_registration_cost_key).update_label
    assert_equal campsites(:yosemite_a), tasks.fetch(campsite_a_registration_cost_key).update_campsite
    assert tasks.fetch(campsite_b_registered_by_key).overrideable?

    campsites(:yosemite_b).update!(registered_by: users(:sam), registration_number: "YO-2026-A13")

    tasks = tasks_by_key(trip.reload)

    assert tasks.fetch(campsite_b_registered_by_key).complete?
    assert tasks.fetch(campsite_b_registration_number_key).complete?
  end

  test "empty campsite checks are incomplete" do
    trip = Trip.create!(
      name: "Empty Readiness Trip",
      location: "Nowhere",
      start_date: Date.new(2026, 9, 1),
      end_date: Date.new(2026, 9, 3)
    )
    tasks = tasks_by_key(trip)

    assert_not tasks.fetch("campsites_added").complete?
    assert_equal "No campsites have been added yet.", tasks.fetch("campsites_added").detail
  end

  test "campsite checks can be manually completed per campsite" do
    task_key = "campsite_#{campsites(:yosemite_b).id}_registration_number"
    TripReadinessCompletion.create!(
      trip: trips(:yosemite),
      task_key: task_key,
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    task = tasks_by_key(trips(:yosemite)).fetch(task_key)

    assert task.complete?
    assert_not task.source_complete?
    assert task.overrideable?
    assert_equal users(:alex), task.completion.completed_by
  end

  test "categories include campsites" do
    category_names = TripReadinessChecklist.new(trips(:yosemite)).categories.map(&:name)

    assert_equal [ "Trip", "Campsites", "Participants", "Post Trip" ], category_names
  end

  test "day trip readiness categories exclude campfire campsites and participant sections" do
    trip = create_day_trip!
    checklist = TripReadinessChecklist.new(trip)
    readiness_category_names = checklist.readiness_categories.map(&:name)
    task_keys = checklist.readiness_categories.flat_map(&:tasks).map(&:key)

    assert_equal [ "Trip" ], readiness_category_names
    assert_not_includes task_keys, "group_campfire_planned"
    assert_not_includes task_keys, "all_confirmed_participants_signed_waiver"
    assert_not_includes task_keys, "all_confirmed_primary_participants_paid_or_waived"
    assert_not_includes task_keys, "all_confirmed_participants_assigned_parking"
    assert_not_includes task_keys, "send_redacted_photo_ids"
    assert_includes task_keys, "mountain_project_link_added"
    assert_includes task_keys, "guide_book_link_added"
    assert_includes task_keys, "sun_exposure_added"
    assert_includes task_keys, "verify_enough_lead_climbers"
    assert_equal "verify_enough_lead_climbers", task_keys.second
    assert_equal "Generally want at least a 1:5 ratio to get ropes up", checklist.readiness_categories.flat_map(&:tasks).find { |task| task.key == "verify_enough_lead_climbers" }.detail
    assert_not TripReadinessChecklist.completable_task_key?("group_campfire_planned", trip: trip)
    assert_not TripReadinessChecklist.completable_task_key?("send_redacted_photo_ids", trip: trip)
    assert TripReadinessChecklist.completable_task_key?("mountain_project_link_added", trip: trip)
    assert TripReadinessChecklist.completable_task_key?("guide_book_link_added", trip: trip)
    assert TripReadinessChecklist.completable_task_key?("sun_exposure_added", trip: trip)
    assert_not TripReadinessChecklist.completable_task_key?("mountain_project_link_added", trip: trips(:yosemite))
    assert_not TripReadinessChecklist.completable_task_key?("sun_exposure_added", trip: trips(:yosemite))
    assert TripReadinessChecklist.completable_task_key?("verify_enough_lead_climbers", trip: trip)
  end

  test "day trip lead climber readiness task only appears for sport or trad climbing" do
    trip = create_day_trip!
    trip.update!(climbing_types: [ "bouldering" ])
    checklist = TripReadinessChecklist.new(trip)
    task_keys = checklist.readiness_categories.flat_map(&:tasks).map(&:key)

    assert_not_includes task_keys, "verify_enough_lead_climbers"
    assert_not TripReadinessChecklist.completable_task_key?("verify_enough_lead_climbers", trip: trip)
  end

  test "day trip post trip tasks exclude camping reimbursement and treasurer money tasks" do
    trip = create_day_trip!
    category = TripReadinessChecklist.new(trip).post_trip_category
    task_names = category.tasks.map(&:name)
    task_keys = category.tasks.map(&:key)

    assert_equal [ "Send reminder to participants to upload photos to album" ], task_names
    assert_not_includes task_keys, "all_campsites_reimbursed"
    assert_not_includes task_keys, "send_collected_money_to_treasurer"
    assert_not TripReadinessChecklist.completable_task_key?("all_campsites_reimbursed", trip: trip)
    assert_not TripReadinessChecklist.completable_task_key?("send_collected_money_to_treasurer", trip: trip)
    assert TripReadinessChecklist.completable_task_key?("send_photo_upload_reminder", trip: trip)
  end

  test "participant checks use short labels and can be manually overridden" do
    tasks = tasks_by_key(trips(:yosemite))

    assert_equal "All waivers signed", tasks.fetch("all_confirmed_participants_signed_waiver").name
    assert_equal "All fees paid or waived", tasks.fetch("all_confirmed_primary_participants_paid_or_waived").name
    assert_equal "Parking assigned", tasks.fetch("all_confirmed_participants_assigned_parking").name
    assert_equal "Send out redacted photo ids", tasks.fetch("send_redacted_photo_ids").name
    assert tasks.fetch("all_confirmed_participants_signed_waiver").overrideable?
    assert tasks.fetch("all_confirmed_primary_participants_paid_or_waived").overrideable?
    assert tasks.fetch("all_confirmed_participants_assigned_parking").overrideable?
    assert tasks.fetch("send_redacted_photo_ids").manual?
    assert_not tasks.fetch("send_redacted_photo_ids").complete?
  end

  test "redacted photo id task can be manually completed" do
    TripReadinessCompletion.create!(
      trip: trips(:yosemite),
      task_key: "send_redacted_photo_ids",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    task = tasks_by_key(trips(:yosemite)).fetch("send_redacted_photo_ids")

    assert task.manual?
    assert task.complete?
    assert_equal users(:alex), task.completion.completed_by
  end

  test "participant checks use confirmed participants and ignore waitlisted participants" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: users(:sam)
    )
    configure_trip_parking!(trip, assigned_signup: signup)
    attach_test_waiver_to(signup)
    signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 3000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
    waitlisted_user = User.create!(first_name: "Wendy", last_name: "Waitlist", email: "wendy-readiness@example.com", password: "password")
    create_waitlisted_signup!(trip: trip, user: waitlisted_user)

    tasks = tasks_by_key(trip)

    assert tasks.fetch("all_confirmed_participants_signed_waiver").complete?
    assert tasks.fetch("all_confirmed_primary_participants_paid_or_waived").complete?
    assert tasks.fetch("all_confirmed_participants_assigned_parking").complete?
  end

  test "waiver checks include confirmed guests while payment ignores guests" do
    trip = trips(:yosemite)
    primary_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: users(:sam)
    )
    attach_test_waiver_to(primary_signup)
    primary_signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 3000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
    guest_user = User.create!(first_name: "Gina", last_name: "Guest", email: "gina-readiness@example.com", password: User::DEFAULT_GUEST_PASSWORD, default_password: true)
    guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1
    )

    tasks = tasks_by_key(trip)

    assert_not tasks.fetch("all_confirmed_participants_signed_waiver").complete?
    assert tasks.fetch("all_confirmed_primary_participants_paid_or_waived").complete?
    assert_not tasks.fetch("all_confirmed_participants_assigned_parking").complete?

    attach_test_waiver_to(guest_signup)
    configure_trip_parking!(trip, assigned_signup: primary_signup)

    tasks = tasks_by_key(trip.reload)

    assert tasks.fetch("all_confirmed_participants_signed_waiver").complete?
    assert tasks.fetch("all_confirmed_primary_participants_paid_or_waived").complete?
    assert tasks.fetch("all_confirmed_participants_assigned_parking").complete?
  end

  test "empty participant checks are incomplete" do
    tasks = tasks_by_key(trips(:jtree))

    assert_not tasks.fetch("all_confirmed_participants_signed_waiver").complete?
    assert_not tasks.fetch("all_confirmed_primary_participants_paid_or_waived").complete?
    assert_not tasks.fetch("all_confirmed_participants_assigned_parking").complete?
    assert_equal "No confirmed participants yet.", tasks.fetch("all_confirmed_participants_signed_waiver").detail
  end

  test "trip details email task completes from sent email" do
    TripDetailsEmailTemplate.ensure_defaults!
    template = TripDetailsEmailTemplate.find_by!(area_key: "yosemite")
    task = tasks_by_key(trips(:yosemite)).fetch("send_trip_details_email")

    assert task.automatic?
    assert_not task.complete?
    assert_equal "Create, preview, and send the trip details email before heading out.", task.detail

    trips(:yosemite).create_trip_details_email!(
      trip_details_email_template: template,
      status: "sent",
      subject: "Trip details",
      body_markdown: "Trip details",
      rendered_html_snapshot: "<p>Trip details</p>",
      rendered_text_snapshot: "Trip details",
      template_name_snapshot: "Yosemite",
      template_area_key_snapshot: "yosemite",
      sent_at: Time.current,
      sent_by: users(:alex)
    )

    task = tasks_by_key(trips(:yosemite).reload).fetch("send_trip_details_email")

    assert task.complete?
    assert_equal "Trip details email was sent to participants.", task.detail
  end

  test "post trip reimbursement check requires every reimbursable campsite to be reimbursed" do
    trip = trips(:yosemite)
    campsites(:yosemite_a).update!(
      registration_fee: "84.25",
      registration_reimbursed_at: Time.zone.local(2026, 6, 16),
      registration_reimbursed_by: users(:sam),
      registration_reimbursement_method: "venmo",
      registration_reimbursement_recorded_by: users(:alex)
    )
    campsites(:yosemite_b).update!(registration_fee: "92.50")

    task = tasks_by_key(trip.reload).fetch("all_campsites_reimbursed")

    assert task.automatic?
    assert task.overrideable?
    assert_not task.complete?
    assert_not task.source_complete?
    assert_includes task.detail, "Upper Pines site A13"

    campsites(:yosemite_b).update!(
      registration_reimbursed_at: Time.zone.local(2026, 6, 17),
      registration_reimbursed_by: users(:sam),
      registration_reimbursement_method: "venmo",
      registration_reimbursement_recorded_by: users(:alex)
    )

    task = tasks_by_key(trip.reload).fetch("all_campsites_reimbursed")

    assert task.complete?
    assert task.source_complete?
  end

  private

  def tasks_by_key(trip)
    TripReadinessChecklist.new(trip).categories.flat_map(&:tasks).index_by(&:key)
  end

  def configure_trip_parking!(trip, assigned_signup:)
    first_spot = true
    trip.campsites.includes(:parking_spots).find_each do |campsite|
      campsite.parking_spots.each do |spot|
        if first_spot
          spot.update!(status: "assigned", assigned_campsite_signup: assigned_signup)
          first_spot = false
        else
          spot.update!(status: "first_come_first_serve")
        end
      end
    end
  end

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
