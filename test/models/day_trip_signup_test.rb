require "test_helper"

class DayTripSignupTest < ActiveSupport::TestCase
  test "shared gear summary uses none when no gear is selected" do
    signup = DayTripSignup.new(trip: day_trip, user: users(:sam), climbing_abilities: [ "top_rope" ])

    assert_equal "None", signup.shared_gear_summary
  end

  test "shared gear summary keeps one item readable" do
    signup = DayTripSignup.new(
      trip: day_trip,
      user: users(:sam),
      climbing_abilities: [ "top_rope" ],
      rope_70m: true
    )

    assert_equal "Rope (70m)", signup.shared_gear_summary
  end

  test "shared gear summary separates multiple items with commas" do
    signup = DayTripSignup.new(
      trip: day_trip,
      user: users(:sam),
      climbing_abilities: [ "top_rope" ],
      rope_60m: true,
      quickdraws_and_sport_anchor: true,
      cams_nuts_and_trad_anchor: true
    )

    assert_equal "Rope (60m), Quickdraws and sport anchor, Cams and trad anchor", signup.shared_gear_summary
  end

  private

  def day_trip
    @day_trip ||= Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Gear Summary",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 12),
      description: "Single day cragging.",
      status: "published",
      meeting_time: "08:30",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, hike toward the main wall.",
      participant_capacity: 8,
      climbing_types: [ "sport", "trad" ]
    )
  end
end
