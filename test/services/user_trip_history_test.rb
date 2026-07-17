require "test_helper"

class UserTripHistoryTest < ActiveSupport::TestCase
  test "includes class signups" do
    trip = Trip.create!(
      trip_type: "class_trip",
      name: "Intro to Anchors",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 10, 12),
      status: "published",
      participant_capacity: 8,
      partner_company: partner_companies(:vertical_world),
      class_signup_url: "https://example.com/classes/anchors",
      class_original_price: "$250",
      weather_url: "https://forecast.weather.gov/castle-rock"
    )
    signup = ClassSignup.create!(trip: trip, user: users(:sam))

    row = UserTripHistory.for_user(users(:sam)).find { |candidate| candidate.signup == signup }

    assert row.class_trip?
    assert_equal trip, row.trip
    assert_equal "Confirmed", row.status_label
    assert_empty row.ledger_entries
  end
end
