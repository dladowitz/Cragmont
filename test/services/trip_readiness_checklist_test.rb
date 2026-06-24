require "test_helper"

class TripReadinessChecklistTest < ActiveSupport::TestCase
  test "marks trip setup tasks complete from existing trip data" do
    trip = trips(:yosemite)
    trip.update!(
      whatsapp_group: "https://chat.whatsapp.com/yosemite-readiness",
      weather_url: "https://forecast.weather.gov/yosemite-readiness",
      photo_album_url: "https://photos.app.goo.gl/yosemite-readiness"
    )

    tasks = tasks_by_key(trip)

    assert tasks.fetch("campsite_coordinator_assigned").complete?
    assert tasks.fetch("whatsapp_group_created").complete?
    assert tasks.fetch("weather_link_added").complete?
    assert tasks.fetch("create_google_photo_album").complete?
  end

  test "rejects unsafe resource urls for automatic tasks" do
    trip = trips(:yosemite)
    trip.update!(
      whatsapp_group: "javascript:alert(1)",
      weather_url: "not a url",
      photo_album_url: "ftp://example.com/album"
    )

    tasks = tasks_by_key(trip)

    assert_not tasks.fetch("whatsapp_group_created").complete?
    assert_not tasks.fetch("weather_link_added").complete?
    assert_not tasks.fetch("create_google_photo_album").complete?
  end

  test "manual overrides can complete selected automatic trip tasks" do
    trip = trips(:yosemite)
    trip.update!(photo_album_url: nil)
    TripReadinessCompletion.create!(
      trip: trip,
      task_key: "create_google_photo_album",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    task = tasks_by_key(trip).fetch("create_google_photo_album")

    assert task.automatic?
    assert task.overrideable?
    assert task.complete?
    assert_not task.source_complete?
    assert_equal "Add Album", task.update_label
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

  test "participant checks use short labels and can be manually overridden" do
    tasks = tasks_by_key(trips(:yosemite))

    assert_equal "All waivers signed", tasks.fetch("all_confirmed_participants_signed_waiver").name
    assert_equal "All fees paid or waived", tasks.fetch("all_confirmed_primary_participants_paid_or_waived").name
    assert_equal "Parking assigned", tasks.fetch("all_confirmed_participants_assigned_parking").name
    assert tasks.fetch("all_confirmed_participants_signed_waiver").overrideable?
    assert tasks.fetch("all_confirmed_primary_participants_paid_or_waived").overrideable?
    assert tasks.fetch("all_confirmed_participants_assigned_parking").overrideable?
  end

  test "participant checks use confirmed participants and ignore waitlisted participants" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: users(:sam),
      parking_status: "reserved_spot"
    )
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

  test "waiver and parking checks include confirmed guests while payment ignores guests" do
    trip = trips(:yosemite)
    primary_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: users(:sam),
      parking_status: "reserved_spot"
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
      guest_position: 1,
      parking_status: "unassigned"
    )

    tasks = tasks_by_key(trip)

    assert_not tasks.fetch("all_confirmed_participants_signed_waiver").complete?
    assert tasks.fetch("all_confirmed_primary_participants_paid_or_waived").complete?
    assert_not tasks.fetch("all_confirmed_participants_assigned_parking").complete?

    attach_test_waiver_to(guest_signup)
    guest_signup.update!(parking_status: "first_come_first_serve")

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

  test "manual task completion comes from persisted records" do
    TripReadinessCompletion.create!(
      trip: trips(:yosemite),
      task_key: "send_trip_details_email",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    task = tasks_by_key(trips(:yosemite)).fetch("send_trip_details_email")

    assert task.manual?
    assert task.complete?
    assert_equal "Person who registered site, Registration number and redacted photo id", task.detail
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
end
