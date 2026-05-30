require "test_helper"

class CampsiteTest < ActiveSupport::TestCase
  test "requires core fields" do
    campsite = Campsite.new

    assert_not campsite.valid?
    assert_includes campsite.errors[:trip], "must exist"
    assert_includes campsite.errors[:campground], "must exist"
    assert_includes campsite.errors[:site_number], "can't be blank"
    assert_includes campsite.errors[:arrival_date], "can't be blank"
    assert_includes campsite.errors[:checkout_date], "can't be blank"
    assert_includes campsite.errors[:participant_capacity], "can't be blank"
    assert_includes campsite.errors[:car_capacity], "can't be blank"
  end

  test "participant capacity must be between zero and fifty" do
    campsite = campsites(:yosemite_a)

    campsite.participant_capacity = -1
    assert_not campsite.valid?
    assert_includes campsite.errors[:participant_capacity], "must be greater than or equal to 0"

    campsite.participant_capacity = 51
    assert_not campsite.valid?
    assert_includes campsite.errors[:participant_capacity], "must be less than or equal to 50"
  end

  test "car capacity must be non negative" do
    campsite = campsites(:yosemite_a)
    campsite.car_capacity = -1

    assert_not campsite.valid?
    assert_includes campsite.errors[:car_capacity], "must be greater than or equal to 0"
  end

  test "checkout date must be after arrival date" do
    campsite = campsites(:yosemite_a)
    campsite.checkout_date = campsite.arrival_date

    assert_not campsite.valid?
    assert_includes campsite.errors[:checkout_date], "must be after the arrival date"
  end

  test "reservation dates must be within trip dates" do
    campsite = campsites(:yosemite_a)

    campsite.arrival_date = trips(:yosemite).start_date - 1.day
    assert_not campsite.valid?
    assert_includes campsite.errors[:arrival_date], "must be within the trip dates"

    campsite.arrival_date = trips(:yosemite).start_date
    campsite.checkout_date = trips(:yosemite).end_date + 1.day
    assert_not campsite.valid?
    assert_includes campsite.errors[:checkout_date], "must be within the trip dates"
  end

  test "summarizes campsite signup capacity" do
    campsite = campsites(:yosemite_a)
    CampsiteSignup.create!(campsite: campsite, user: users(:sam))

    assert_equal 1, campsite.confirmed_signup_count
    assert_equal 5, campsite.available_participant_capacity
  end

  test "campsite full status uses campsite signups" do
    campsite = campsites(:yosemite_a)
    campsite.participant_capacity.times do |index|
      CampsiteSignup.create!(campsite: campsite, user: User.create!(
        first_name: "Full",
        last_name: "Site#{index}",
        email: "full-site#{index}@example.com",
        password: "password"
      ))
    end

    assert campsite.capacity_full?
    assert_equal 0, campsite.available_participant_capacity
  end
end
