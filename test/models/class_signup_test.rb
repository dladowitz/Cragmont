require "test_helper"

class ClassSignupTest < ActiveSupport::TestCase
  test "requires a class trip" do
    signup = ClassSignup.new(trip: trips(:yosemite), user: users(:sam))

    assert_not signup.valid?
    assert_includes signup.errors[:trip], "must be a class"
  end

  test "allows one active signup per user and class" do
    trip = class_trip!
    ClassSignup.create!(trip: trip, user: users(:sam))

    duplicate = ClassSignup.new(trip: trip, user: users(:sam))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already signed up for this class"

    ClassSignup.find_by!(trip: trip, user: users(:sam)).update!(status: "canceled")
    assert ClassSignup.new(trip: trip, user: users(:sam)).valid?
  end

  private

  def class_trip!
    Trip.create!(
      trip_type: "class_trip",
      name: "Intro to Anchors",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 10, 12),
      status: "published",
      participant_capacity: 8,
      partner_company: partner_companies(:vertical_world),
      class_signup_url: "https://example.com/classes/anchors",
      class_original_price: "$200",
      weather_url: "https://forecast.weather.gov/castle-rock"
    )
  end
end
