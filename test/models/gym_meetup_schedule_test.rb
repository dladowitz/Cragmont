require "test_helper"

class GymMeetupScheduleTest < ActiveSupport::TestCase
  test "a one off outing does not require recurrence fields or a coordinator" do
    schedule = build_schedule(frequency: "none", ends_on: nil)
    schedule.trip.campsite_coordinator = nil

    assert_difference "Trip.count", 1 do
      assert schedule.save
    end
    assert_equal [ Date.new(2026, 1, 1) ], schedule.created_trips.map(&:start_date)
  end

  test "twice monthly dates cross the year and include the end date" do
    schedule = build_schedule(start_date: "2025-12-04", ends_on: "2026-01-15")

    assert_equal %w[2025-12-04 2025-12-18 2026-01-01 2026-01-15], schedule.dates.map(&:iso8601)
  end

  test "second and fourth weekdays skip fifth weeks" do
    schedule = build_schedule(start_date: "2026-01-08", frequency: "second_fourth", ends_on: "2026-02-28")

    assert_equal %w[2026-01-08 2026-01-22 2026-02-12 2026-02-26], schedule.dates.map(&:iso8601)
  end

  test "monthly keeps the weekday ordinal through leap February" do
    schedule = build_schedule(start_date: "2028-01-28", frequency: "monthly", ends_on: "2028-03-24")

    assert_equal %w[2028-01-28 2028-02-25 2028-03-24], schedule.dates.map(&:iso8601)
  end

  test "invalid recurrence inputs never create partial outings" do
    [
      { frequency: "weekly" },
      { ends_on: nil },
      { ends_on: "invalid" },
      { ends_on: "2026-01-01" },
      { ends_on: "2025-12-31" },
      { ends_on: "2027-01-02" },
      { start_date: nil },
      { start_date: "2026-01-29", frequency: "monthly" },
      { start_date: "2026-01-08", frequency: "first_third" },
      { start_date: "2026-01-01", frequency: "second_fourth" }
    ].each do |attributes|
      schedule = build_schedule(**attributes)
      assert_no_difference "Trip.count" do
        refute schedule.save, attributes.inspect
      end
      assert schedule.errors.any?, attributes.inspect
    end
    assert build_schedule(ends_on: "2027-01-01").valid?
  end

  test "repeat requires a gym outing and a host" do
    schedule = build_schedule
    schedule.trip.campsite_coordinator = nil
    refute schedule.valid?
    assert_match /Coordinator/, schedule.errors.full_messages.join

    schedule.trip.campsite_coordinator = users(:alex)
    schedule.trip.trip_type = "camping"
    refute schedule.valid?
    assert_match /Only gym outings/, schedule.errors.full_messages.join
  end

  test "a later save failure rolls back every date" do
    schedule = build_schedule
    failure = ->(trip) { trip.errors.add(:base, "Second date rejected") if trip.start_date == Date.new(2026, 1, 15) }
    Trip.validate failure

    assert_no_difference "Trip.count" do
      refute schedule.save
    end
    assert schedule.trip.new_record?
    assert_match /Second date rejected/, schedule.trip.errors.full_messages.join
  ensure
    Trip.skip_callback(:validate, :before, failure) if failure
  end

  test "each date reuses the image blob without copying participants" do
    schedule = build_schedule
    schedule.trip.day_trip_image.attach(io: StringIO.new(Base64.decode64(SIGNATURE_DATA_URL.split(",").last)), filename: "gym.png", content_type: "image/png")

    assert_difference "ActiveStorage::Blob.count", 1 do
      assert schedule.save
    end
    first, second = schedule.created_trips
    assert_equal first.day_trip_image.blob_id, second.day_trip_image.blob_id
    assert_equal 2, ActiveStorage::Attachment.where(record: schedule.created_trips, name: "day_trip_image").count
    DayTripSignup.create!(trip: first, user: users(:sam), climbing_abilities: [ "none" ])
    assert_empty second.day_trip_signups
    assert_equal 1, first.day_trip_signups.count
  end

  test "calendar times stay at one pm Pacific across spring and fall DST" do
    [
      [ "2026-02-08", "2026-04-12", %w[20260208T210000Z 20260308T200000Z 20260412T200000Z] ],
      [ "2026-10-04", "2026-12-06", %w[20261004T200000Z 20261101T210000Z 20261206T210000Z] ]
    ].each do |start_date, ends_on, utc_times|
      schedule = build_schedule(start_date: start_date, ends_on: ends_on, frequency: "monthly")
      assert schedule.save
      calendar = TripCalendar.new(schedule.created_trips, url_options: { host: "example.com" }).render
      assert_equal utc_times, calendar.scan(/^DTSTART:(\S+)/).flatten
      assert_equal schedule.created_trips.map(&:start_date), schedule.created_trips.map(&:end_date)
    end
  end

  private

  def build_schedule(start_date: "2026-01-01", frequency: "first_third", ends_on: "2026-01-15")
    trip = Trip.new(name: "Monthly gym crew", location: "Movement Sunnyvale", trip_type: "gym_outing", start_date: start_date,
      meeting_time: "13:00", end_time: "15:00", participant_capacity: 10, status: "published", campsite_coordinator: users(:alex))
    GymMeetupSchedule.new(trip: trip, frequency: frequency, ends_on: ends_on)
  end
end
