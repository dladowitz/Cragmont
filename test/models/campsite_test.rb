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

  test "participant capacity must be between four and eight" do
    campsite = campsites(:yosemite_a)

    campsite.participant_capacity = 3
    assert_not campsite.valid?
    assert_includes campsite.errors[:participant_capacity], "must be greater than or equal to 4"

    campsite.participant_capacity = 9
    assert_not campsite.valid?
    assert_includes campsite.errors[:participant_capacity], "must be less than or equal to 8"
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
end
