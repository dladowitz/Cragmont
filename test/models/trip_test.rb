require "test_helper"

class TripTest < ActiveSupport::TestCase
  test "requires core fields" do
    trip = Trip.new

    assert_not trip.valid?
    assert_includes trip.errors[:name], "can't be blank"
    assert_includes trip.errors[:location], "can't be blank"
    assert_includes trip.errors[:start_date], "can't be blank"
    assert_includes trip.errors[:end_date], "can't be blank"
  end

  test "requires known status" do
    trip = trips(:yosemite)

    assert_raises ArgumentError do
      trip.status = "cancelled"
    end
  end

  test "requires end date on or after start date" do
    trip = trips(:yosemite)
    trip.end_date = trip.start_date - 1.day

    assert_not trip.valid?
    assert_includes trip.errors[:end_date], "must be on or after the start date"
  end

  test "published trip requires campsite coordinator" do
    trip = trips(:yosemite)
    trip.campsite_coordinator = nil

    assert_not trip.valid?
    assert_includes trip.errors[:campsite_coordinator], "can't be blank"
  end

  test "draft and archived trips do not require campsite coordinator" do
    trip = trips(:jtree)
    trip.campsite_coordinator = nil

    trip.status = "draft"
    assert trip.valid?

    trip.status = "archived"
    assert trip.valid?
  end

  test "summarizes campsite capacity" do
    trip = trips(:yosemite)

    assert_equal 2, trip.campsite_count
    assert_equal 10, trip.total_participant_capacity
    assert_equal 3, trip.total_car_capacity
  end

  test "summarizes available participant capacity" do
    trip = trips(:yosemite)
    TripSignup.create!(trip: trip, user: users(:sam))

    assert_equal 9, trip.available_participant_capacity
  end

  test "capacity count includes minors at the age limit and excludes younger minors" do
    trip = trips(:yosemite)
    signup = TripSignup.create!(trip: trip, user: users(:sam))
    signup.trip_signup_minors.create!(first_name: "Young", last_name: "Minor", age: 12, relationship: "Child")
    signup.trip_signup_minors.create!(first_name: "Teen", last_name: "Minor", age: 13, relationship: "Child")

    assert_equal 2, trip.confirmed_signup_count
    assert_equal 1, trip.confirmed_uncounted_minor_count
    assert_equal 8, trip.available_participant_capacity
  end

  test "capacity count uses configured uncounted minor age limit" do
    SiteSetting.current.update!(uncounted_minor_age_limit: 15)
    trip = trips(:yosemite)
    signup = TripSignup.create!(trip: trip, user: users(:sam))
    signup.trip_signup_minors.create!(first_name: "Teen", last_name: "Minor", age: 14, relationship: "Child")

    assert_equal 1, trip.confirmed_signup_count
    assert_equal 1, trip.confirmed_uncounted_minor_count
    assert_equal 9, trip.available_participant_capacity
  ensure
    SiteSetting.current.update!(uncounted_minor_age_limit: 13)
  end

  test "knows when capacity is almost full" do
    trip = trips(:yosemite)
    6.times do |index|
      TripSignup.create!(trip: trip, user: User.create!(
        first_name: "Almost",
        last_name: "Full#{index}",
        email: "almost-full#{index}@example.com",
        password: "password"
      ))
    end

    assert trip.almost_full?
    assert_not trip.capacity_full?
  end
end
