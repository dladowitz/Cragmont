require "test_helper"

class ClimbingPartnerRequestTest < ActiveSupport::TestCase
  test "only one request is allowed per climber and trip" do
    ClimbingPartnerRequest.create!(trip: trips(:yosemite), user: users(:sam))
    duplicate = ClimbingPartnerRequest.new(trip: trips(:yosemite), user: users(:sam))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "request must belong to a camping trip" do
    day_trip = trips(:yosemite)
    day_trip.trip_type = "day_trip"
    partner_request = ClimbingPartnerRequest.new(trip: day_trip, user: users(:sam))

    assert_not partner_request.valid?
    assert_includes partner_request.errors[:trip], "must be a camping trip"
  end
end
