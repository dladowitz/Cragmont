require "test_helper"

class Admin::TripParticipantEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "camping trip page shows confirmed and waitlisted email lists with copy controls" do
    trip = trips(:yosemite)
    confirmed_guest = user!("Gina", "Guest", "gina-copy@example.com")
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: confirmed_guest,
      guest_of_signup: primary_signup,
      guest_position: 1
    )
    missing_email_user = User.create!(first_name: "Mina", last_name: "Missing", password: "password")
    create_campsite_signup!(campsite: campsites(:yosemite_b), user: missing_email_user)
    waitlisted_user = user!("Wendy", "Wait", "wendy-copy@example.com")
    create_waitlisted_signup!(trip: trip, user: waitlisted_user)

    get participant_emails_admin_trip_url(trip)

    assert_response :success
    assert_select "h2", "Participant Emails"
    assert_select "a[href='#{admin_trip_path(trip)}']", text: "Back to trip"
    assert_select "[data-controller='copy-text']", count: 2
    assert_select "button[data-action='copy-text#copy']", text: "Copy Email Addresses", count: 2
    assert_equal "sam@example.com, gina-copy@example.com",
      css_select("textarea#confirmed-participants-email-addresses").first.text
    assert_equal "wendy-copy@example.com",
      css_select("textarea#waitlist-email-addresses").first.text
    assert_select ".participant-email-section", text: /Confirmed Participants/
    assert_select ".participant-email-name", text: "Sam Lee"
    assert_select ".participant-email-name", text: "Gina Guest"
    assert_select ".participant-email-name", text: "Mina Missing"
    assert_select ".participant-email-address.is-missing", text: "Missing email"
    assert_select ".participant-email-section", text: /Waitlist/
    assert_select ".participant-email-name", text: "Wendy Wait"
  end

  test "day trip page shows confirmed and waitlisted email lists" do
    trip = day_trip!
    DayTripSignup.create!(trip: trip, user: user!("Dara", "Day", "dara-copy@example.com"), climbing_abilities: [ "top_rope" ])
    DayTripSignup.create!(trip: trip, user: user!("Willa", "Wait", "willa-copy@example.com"), status: "waitlisted", climbing_abilities: [ "lead" ])

    get participant_emails_admin_trip_url(trip)

    assert_response :success
    assert_equal "dara-copy@example.com",
      css_select("textarea#confirmed-participants-email-addresses").first.text
    assert_equal "willa-copy@example.com",
      css_select("textarea#waitlist-email-addresses").first.text
    assert_select ".participant-email-name", text: "Dara Day"
    assert_select ".participant-email-name", text: "Willa Wait"
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
