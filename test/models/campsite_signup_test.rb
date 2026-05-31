require "test_helper"

class CampsiteSignupTest < ActiveSupport::TestCase
  test "requires campsite and user" do
    signup = CampsiteSignup.new

    assert_not signup.valid?
    assert_includes signup.errors[:campsite], "can't be blank"
    assert_includes signup.errors[:trip], "must exist"
    assert_includes signup.errors[:user], "must exist"
  end

  test "waitlisted signup can be trip level without campsite or dates" do
    signup = CampsiteSignup.new(trip: trips(:yosemite), user: users(:sam), status: "waitlisted")

    assert signup.valid?
    assert_equal "Not chosen yet", signup.attendance_date_range
    assert_equal "Not chosen yet", signup.compact_attendance_date_range
  end

  test "requires known status" do
    assert_raises ArgumentError do
      CampsiteSignup.new(status: "cancelled")
    end
  end

  test "prevents duplicate signup for the same user and trip" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    duplicate = CampsiteSignup.new(campsite: campsites(:yosemite_b), user: users(:sam))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already signed up for this trip"
  end

  test "signup is confirmed while capacity remains" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert signup.confirmed?
    assert_equal trips(:yosemite), signup.trip
  end

  test "campsite must belong to the selected trip" do
    signup = CampsiteSignup.new(trip: trips(:yosemite), campsite: campsites(:jtree_a), user: users(:sam))

    assert_not signup.valid?
    assert_includes signup.errors[:campsite], "must belong to the selected trip"
  end

  test "requires valid minor details" do
    signup = CampsiteSignup.new(campsite: campsites(:yosemite_a), user: users(:sam))
    minor = signup.campsite_signup_minors.build(first_name: "Mika", last_name: "", age: 18, relationship: "")

    assert_not signup.valid?
    assert_not minor.valid?
    assert_includes minor.errors[:last_name], "can't be blank"
    assert_includes minor.errors[:relationship], "can't be blank"
    assert_includes minor.errors[:age], "must be less than 18"
  end

  test "limits signup to two minors" do
    signup = CampsiteSignup.new(campsite: campsites(:yosemite_a), user: users(:sam))
    3.times do |index|
      signup.campsite_signup_minors.build(first_name: "Minor", last_name: "Person#{index}", age: 10, relationship: "Child")
    end

    assert_not signup.valid?
    assert_includes signup.errors[:campsite_signup_minors], "cannot include more than 2 minors"
  end

  test "signup is waitlisted after capacity is filled" do
    campsite = campsites(:yosemite_a)
    campsite.participant_capacity.times do |index|
      create_campsite_signup!(campsite: campsite, user: User.create!(
        first_name: "Confirmed",
        last_name: "Person#{index}",
        email: "confirmed#{index}@example.com",
        password: "password"
      ))
    end

    waitlisted = create_campsite_signup!(campsite: campsite, user: User.create!(
      first_name: "Waiting",
      last_name: "Person",
      email: "waiting@example.com",
      password: "password"
    ))

    assert waitlisted.waitlisted?
  end

  test "knows when waiver is signed" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_not signup.waiver_signed?

    attach_test_waiver_to(signup)

    assert signup.waiver_signed?
  end

  test "calculates capacity count from adult and older minors" do
    signup = CampsiteSignup.new(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.build(first_name: "Young", last_name: "Minor", age: 12, relationship: "Child")
    signup.campsite_signup_minors.build(first_name: "Teen", last_name: "Minor", age: 13, relationship: "Child")

    assert_equal 2, signup.capacity_count
    assert_equal 1, signup.uncounted_minor_count
  end

  test "summarizes public minor age categories" do
    signup = CampsiteSignup.new(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.build(first_name: "Young", last_name: "Minor", age: 9, relationship: "Child")
    signup.campsite_signup_minors.build(first_name: "Teen", last_name: "Minor", age: 12, relationship: "Child")

    assert_equal "1 under 10yrs and 1 over 10yrs", signup.public_minor_age_summary(age_limit: 10)
  end

  test "primary signup can have multiple guests" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    first_guest = User.create!(first_name: "First", last_name: "Guest", email: "first-guest@example.com", password: "password")
    second_guest = User.create!(first_name: "Second", last_name: "Guest", email: "second-guest@example.com", password: "password")

    first_guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: first_guest,
      guest_of_signup: signup,
      guest_position: 1
    )
    second_guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: second_guest,
      guest_of_signup: signup,
      guest_position: 2
    )

    assert_equal [ first_guest_signup, second_guest_signup ], signup.guest_signups.to_a
    assert first_guest_signup.guest?
    assert_equal signup, first_guest_signup.primary_signup
  end

  test "limits primary signup to two guests" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    2.times do |index|
      create_campsite_signup!(
        campsite: campsites(:yosemite_a),
        user: User.create!(first_name: "Allowed", last_name: "Guest#{index}", email: "allowed-guest-#{index}@example.com", password: "password"),
        guest_of_signup: signup,
        guest_position: index + 1
      )
    end

    extra_guest_signup = CampsiteSignup.new(
      campsite: campsites(:yosemite_a),
      user: User.create!(first_name: "Extra", last_name: "Guest", email: "extra-guest@example.com", password: "password"),
      guest_of_signup: signup,
      guest_position: 3
    )

    assert_not extra_guest_signup.valid?
    assert_includes extra_guest_signup.errors[:guest_of_signup], "cannot have more than 2 guests"
  end

  test "guest cannot be linked to another guest" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: User.create!(first_name: "First", last_name: "Guest", email: "nested-first@example.com", password: "password"),
      guest_of_signup: signup,
      guest_position: 1
    )
    nested_guest_signup = CampsiteSignup.new(
      campsite: campsites(:yosemite_a),
      user: User.create!(first_name: "Nested", last_name: "Guest", email: "nested-second@example.com", password: "password"),
      guest_of_signup: guest_signup,
      guest_position: 1
    )

    assert_not nested_guest_signup.valid?
    assert_includes nested_guest_signup.errors[:guest_of_signup], "must be a primary participant signup"
  end

  test "party capacity includes linked guests" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Teen", last_name: "Minor", age: 13, relationship: "Child")
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: User.create!(first_name: "Capacity", last_name: "Guest", email: "capacity-guest@example.com", password: "password"),
      guest_of_signup: signup,
      guest_position: 1
    )

    assert_equal 2, signup.capacity_count
    assert_equal 3, signup.party_capacity_count
  end

  test "builds waiver document filename from signed date participant and campsite" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.waiver_signed_at = Time.zone.local(2026, 5, 25)

    assert_equal "2026-05-25-Sam-Lee-Yosemite-Valley-Spring-A12-#{signup.id}.pdf", signup.waiver_document_filename
  end

  test "confirmed signup can be assigned to a campsite before dates are chosen" do
    signup = CampsiteSignup.new(campsite: campsites(:yosemite_a), user: users(:sam))

    assert signup.valid?
    assert_equal "Not chosen yet", signup.attendance_date_range
  end

  test "attendance dates must be within campsite dates" do
    campsite = campsites(:yosemite_a)
    signup = CampsiteSignup.new(
      campsite: campsite,
      user: users(:sam),
      arrival_date: campsite.arrival_date - 1.day,
      checkout_date: campsite.checkout_date + 1.day
    )

    assert_not signup.valid?
    assert_includes signup.errors[:arrival_date], "must be on or after the campsite arrival date"
    assert_includes signup.errors[:checkout_date], "must be on or before the campsite checkout date"
  end

  test "checkout date must be after arrival date" do
    campsite = campsites(:yosemite_a)
    signup = CampsiteSignup.new(
      campsite: campsite,
      user: users(:sam),
      arrival_date: campsite.arrival_date,
      checkout_date: campsite.arrival_date
    )

    assert_not signup.valid?
    assert_includes signup.errors[:checkout_date], "must be after the arrival date"
  end

  test "calculates night count" do
    signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: users(:sam),
      arrival_date: Date.new(2026, 6, 13),
      checkout_date: Date.new(2026, 6, 15)
    )

    assert_equal 2, signup.night_count
    assert_equal "Jun 13-Jun 15", signup.attendance_date_range
    assert_equal "6/13-6/15", signup.compact_attendance_date_range
  end
end
