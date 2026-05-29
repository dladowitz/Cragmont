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

  test "requires valid minor details" do
    signup = TripSignup.new(trip: trips(:yosemite), user: users(:sam))
    minor = signup.trip_signup_minors.build(first_name: "Mika", last_name: "", age: 18, relationship: "")

    assert_not signup.valid?
    assert_not minor.valid?
    assert_includes minor.errors[:last_name], "can't be blank"
    assert_includes minor.errors[:relationship], "can't be blank"
    assert_includes minor.errors[:age], "must be less than 18"
  end

  test "limits signup to two minors" do
    signup = TripSignup.new(trip: trips(:yosemite), user: users(:sam))
    3.times do |index|
      signup.trip_signup_minors.build(first_name: "Minor", last_name: "Person#{index}", age: 10, relationship: "Child")
    end

    assert_not signup.valid?
    assert_includes signup.errors[:trip_signup_minors], "cannot include more than 2 minors"
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

  test "calculates capacity count from adult and older minors" do
    signup = TripSignup.new(trip: trips(:yosemite), user: users(:sam))
    signup.trip_signup_minors.build(first_name: "Young", last_name: "Minor", age: 12, relationship: "Child")
    signup.trip_signup_minors.build(first_name: "Teen", last_name: "Minor", age: 13, relationship: "Child")

    assert_equal 2, signup.capacity_count
    assert_equal 1, signup.uncounted_minor_count
  end

  test "builds waiver document filename from signed date and participant name" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    signup.waiver_signed_at = Time.zone.local(2026, 5, 25)

    assert_equal "2026-05-25-Sam-Lee-Yosemite-Valley-Spring-#{signup.id}.pdf", signup.waiver_document_filename
  end
end
