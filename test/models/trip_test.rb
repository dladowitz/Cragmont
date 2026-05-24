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

  test "summarizes campsite capacity" do
    trip = trips(:yosemite)

    assert_equal 2, trip.campsite_count
    assert_equal 10, trip.total_participant_capacity
    assert_equal 3, trip.total_car_capacity
  end
end
