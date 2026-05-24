require "test_helper"

class TripSignupTest < ActiveSupport::TestCase
  test "requires trip and user" do
    signup = TripSignup.new

    assert_not signup.valid?
    assert_includes signup.errors[:trip], "must exist"
    assert_includes signup.errors[:user], "must exist"
  end

  test "requires known status" do
    assert_raises ArgumentError do
      TripSignup.new(status: "cancelled")
    end
  end

  test "prevents duplicate signup for the same user and trip" do
    TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    duplicate = TripSignup.new(trip: trips(:yosemite), user: users(:sam))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already signed up for this trip"
  end

  test "signup is confirmed while capacity remains" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))

    assert signup.confirmed?
  end

  test "signup is waitlisted after capacity is filled" do
    trip = trips(:yosemite)
    trip.total_participant_capacity.times do |index|
      TripSignup.create!(trip: trip, user: User.create!(
        first_name: "Confirmed",
        last_name: "Person#{index}",
        email: "confirmed#{index}@example.com",
        password: "password"
      ))
    end

    waitlisted = TripSignup.create!(trip: trip, user: User.create!(
      first_name: "Waiting",
      last_name: "Person",
      email: "waiting@example.com",
      password: "password"
    ))

    assert waitlisted.waitlisted?
  end

  test "knows when waiver is signed" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))

    assert_not signup.waiver_signed?

    attach_test_waiver_to(signup)

    assert signup.waiver_signed?
  end
end
