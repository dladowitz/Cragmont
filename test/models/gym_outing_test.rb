require "test_helper"

class GymOutingTest < ActiveSupport::TestCase
  setup do
    @trip = Trip.create!(
      trip_type: "gym_outing", name: "Friday gym laps", location: "Movement, San Francisco",
      start_date: Date.new(2026, 10, 16), meeting_time: "18:00", end_time: "20:00",
      status: "published", participant_capacity: 3
    )
  end

  test "gym outings use single day dates and require time and positive capacity without outdoor details" do
    assert @trip.gym_outing?
    assert @trip.single_day_event?
    assert @trip.uses_day_trip_signups?
    assert_not @trip.day_trip?
    assert_equal "Gym Outing", @trip.trip_type_label
    assert_equal @trip.start_date, @trip.end_date
    assert_empty @trip.climbing_types

    @trip.assign_attributes(meeting_time: nil, participant_capacity: 0)
    assert_not @trip.valid?
    assert @trip.errors[:meeting_time].present?
    assert @trip.errors[:participant_capacity].present?
    assert_empty @trip.errors[:meeting_location_url]
    assert_empty @trip.errors[:late_arrival_instructions]
  end

  test "gym capacity includes minors but excludes waitlisted participants" do
    signup = DayTripSignup.create!(trip: @trip, user: users(:sam), climbing_abilities: [ "none" ])
    signup.day_trip_signup_minors.create!(first_name: "Little", last_name: "Climber", age: 10, relationship: "Child")
    DayTripSignup.create!(trip: @trip, user: users(:alex), climbing_abilities: [ "none" ], status: "waitlisted")

    assert_equal 3, @trip.total_participant_capacity
    assert_equal 2, @trip.confirmed_capacity_count
    assert_equal 1, @trip.available_participant_capacity
    assert @trip.available_for_day_trip_party?(lead_count: 0, top_rope_count: 1)
    assert_not @trip.available_for_day_trip_party?(lead_count: 0, top_rope_count: 2)
    assert_equal 0, @trip.campsite_count
    assert @trip.delete_blocked_by_participants?
  end

  test "gym participants appear in email lists and user history" do
    signup = DayTripSignup.create!(trip: @trip, user: users(:sam), climbing_abilities: [ "none" ])
    DayTripSignup.create!(trip: @trip, user: users(:alex), climbing_abilities: [ "none" ], status: "waitlisted")
    emails = TripParticipantEmailList.new(@trip)
    assert_equal [ users(:sam).email ], emails.confirmed_email_addresses
    assert_equal [ users(:alex).email ], emails.waitlisted_email_addresses
    assert_includes UserTripHistory.for_user(users(:sam)).map(&:signup), signup
  end

  test "gym readiness omits outdoor and camping tasks" do
    checklist = TripReadinessChecklist.new(@trip)
    assert_equal %w[trip post_trip], checklist.categories.map(&:key)
    excluded = TripReadinessChecklist::DAY_TRIP_EXCLUDED_TASKS + TripReadinessChecklist::GYM_OUTING_EXCLUDED_TASKS
    keys = checklist.categories.flat_map(&:tasks).map(&:key)
    excluded.each do |key|
      assert_not_includes keys, key
      assert_not TripReadinessChecklist.completable_task_key?(key, trip: @trip)
    end
    assert_includes keys, "campsite_coordinator_assigned"
    assert_includes keys, "whatsapp_group_created"
  end
end
