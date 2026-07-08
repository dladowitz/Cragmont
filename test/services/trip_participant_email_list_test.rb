require "test_helper"

class TripParticipantEmailListTest < ActiveSupport::TestCase
  test "lists confirmed and waitlisted camping participant emails separately" do
    trip = trips(:yosemite)
    confirmed_primary = create_campsite_signup!(campsite: campsites(:yosemite_a), user: user!("Avery", "Anchor", "avery-anchor@example.com"))
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: user!("Gina", "Guest", "gina-guest@example.com"),
      guest_of_signup: confirmed_primary,
      guest_position: 1
    )
    waitlisted_primary = create_waitlisted_signup!(trip: trip, user: user!("Wendy", "Wait", "wendy-wait@example.com"))
    create_waitlisted_signup!(
      trip: trip,
      user: user!("Gary", "Guest", "gary-guest@example.com"),
      guest_of_signup: waitlisted_primary,
      guest_position: 1
    )
    create_campsite_signup!(campsite: campsites(:yosemite_b), user: user!("Parker", "Pending", "parker-pending@example.com"), status: "pending_payment")
    create_campsite_signup!(campsite: campsites(:yosemite_b), user: user!("Cara", "Canceled", "cara-canceled@example.com"), status: "canceled")

    email_list = TripParticipantEmailList.new(trip)

    assert_equal [ "Avery Anchor", "Gina Guest" ], email_list.confirmed_participants.map(&:name)
    assert_equal [ "avery-anchor@example.com", "gina-guest@example.com" ], email_list.confirmed_email_addresses
    assert_equal [ "Wendy Wait", "Gary Guest" ], email_list.waitlisted_participants.map(&:name)
    assert_equal [ "wendy-wait@example.com", "gary-guest@example.com" ], email_list.waitlisted_email_addresses
  end

  test "lists confirmed and waitlisted day trip participant emails separately" do
    trip = day_trip!
    confirmed_primary = DayTripSignup.create!(trip: trip, user: user!("Dara", "Day", "dara-day@example.com"), climbing_abilities: [ "top_rope" ])
    DayTripSignup.create!(
      trip: trip,
      user: user!("Oscar", "Guest", "oscar-guest@example.com"),
      guest_of_day_trip_signup: confirmed_primary,
      guest_position: 1,
      climbing_abilities: [ "top_rope" ]
    )
    waitlisted_primary = DayTripSignup.create!(trip: trip, user: user!("Willow", "Wait", "willow-wait@example.com"), status: "waitlisted", climbing_abilities: [ "lead" ])
    DayTripSignup.create!(
      trip: trip,
      user: user!("Nina", "Guest", "nina-guest@example.com"),
      guest_of_day_trip_signup: waitlisted_primary,
      guest_position: 1,
      status: "waitlisted",
      climbing_abilities: [ "lead" ]
    )
    DayTripSignup.create!(trip: trip, user: user!("Cory", "Canceled", "cory-canceled@example.com"), status: "canceled", climbing_abilities: [ "top_rope" ])

    email_list = TripParticipantEmailList.new(trip)

    assert_equal [ "Dara Day", "Oscar Guest" ], email_list.confirmed_participants.map(&:name)
    assert_equal [ "dara-day@example.com", "oscar-guest@example.com" ], email_list.confirmed_email_addresses
    assert_equal [ "Willow Wait", "Nina Guest" ], email_list.waitlisted_participants.map(&:name)
    assert_equal [ "willow-wait@example.com", "nina-guest@example.com" ], email_list.waitlisted_email_addresses
  end

  private

  def user!(first_name, last_name, email)
    User.create!(first_name: first_name, last_name: last_name, email: email, password: "password")
  end

  def day_trip!
    Trip.create!(
      trip_type: "day_trip",
      name: "Castle Rock Day",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 8, 1),
      description: "Single day cragging.",
      status: "published",
      meeting_time: "08:30",
      meeting_location: "Castle Rock Parking",
      meeting_location_url: "https://maps.google.com/?q=Castle+Rock",
      late_arrival_instructions: "If you are running late, hike toward the main wall.",
      participant_capacity: 6,
      climbing_types: [ "sport" ]
    )
  end
end
