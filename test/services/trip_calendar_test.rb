require "test_helper"

class TripCalendarTest < ActiveSupport::TestCase
  test "all day camping spans the inclusive trip dates and has stable identity and update timestamps" do
    trip = trips(:yosemite)
    calendar = render_calendar(trip)

    assert_includes calendar, "DTSTART;VALUE=DATE:20260612\r\n"
    assert_includes calendar, "DTEND;VALUE=DATE:20260616\r\n"
    assert_includes calendar, "UID:trip-#{trip.id}@cragmontclimbing.com\r\n"
    assert_includes calendar, "URL:https://www.cragmontclimbing.com/trips/#{trip.id}\r\n"
    assert_equal calendar, render_calendar(trip)

    original_uid = calendar.lines.find { |line| line.start_with?("UID:") }
    trip.name = "New trip name"
    trip.updated_at = Time.utc(2026, 9, 10, 17)
    updated = render_calendar(trip)
    assert_includes updated, original_uid
    assert_includes updated, "LAST-MODIFIED:20260910T170000Z\r\n"
    assert_includes updated, "DTSTAMP:20260910T170000Z\r\n"
    assert_includes updated, "SUMMARY:New trip name\r\n"
  end

  test "meeting times use Pacific daylight and standard time without relying on application timezone" do
    trip = trips(:yosemite)
    trip.assign_attributes(trip_type: "day_trip", start_date: Date.new(2026, 7, 12), meeting_time: "08:30", end_time: "16:00")
    calendar = render_calendar(trip)
    assert_includes calendar, "DTSTART:20260712T153000Z\r\n"
    assert_includes calendar, "DTEND:20260712T230000Z\r\n"

    trip.start_date = Date.new(2026, 12, 12)
    calendar = render_calendar(trip)
    assert_includes calendar, "DTSTART:20261212T163000Z\r\n"
    assert_includes calendar, "DTEND:20261213T000000Z\r\n"
  end

  test "late outings can end after midnight and unspecified end times are not invented" do
    trip = trips(:yosemite)
    trip.assign_attributes(trip_type: "day_trip", start_date: Date.new(2026, 9, 10), meeting_time: "22:00", end_time: "01:00")
    assert_includes render_calendar(trip), "DTEND:20260911T080000Z\r\n"

    trip.end_time = nil
    refute_includes render_calendar(trip), "DTEND"
  end

  test "single day events without a meeting time use one all day date" do
    trip = trips(:yosemite)
    trip.assign_attributes(trip_type: "class_trip", start_date: Date.new(2026, 9, 10), end_date: Date.new(2026, 9, 10))
    calendar = render_calendar(trip)
    assert_includes calendar, "DTSTART;VALUE=DATE:20260910\r\n"
    assert_includes calendar, "DTEND;VALUE=DATE:20260911\r\n"
  end

  test "text is escaped and folded at 75 octets without splitting UTF8 or permitting property injection" do
    trip = trips(:yosemite)
    trip.name = "Crag, slab; rope\\line\r\nBEGIN:VEVENT\n#{'🧗é' * 30}"
    calendar = render_calendar(trip)

    assert calendar.valid_encoding?
    assert calendar.end_with?("END:VCALENDAR\r\n")
    assert_equal 1, calendar.lines.count { |line| line == "BEGIN:VEVENT\r\n" }
    calendar.split("\r\n").each do |line|
      assert_operator line.bytesize, :<=, 75
      assert line.valid_encoding?
    end
    refute_match(/(?<!\r)\n|\r(?!\n)/, calendar)
    unfolded = calendar.gsub("\r\n ", "")
    assert_includes unfolded, "SUMMARY:Crag\\, slab\\; rope\\\\line\\nBEGIN:VEVENT\\n#{'🧗é' * 30}\r\n"
  end

  test "private links and contacts never appear even when pasted into title location or notes" do
    trip = trips(:yosemite)
    trip.whatsapp_group = "https://chat.whatsapp.com/secret-invite"
    trip.photo_album_url = "https://photos.example.test/private-album"
    trip.name = "Climb #{trip.whatsapp_group}"
    trip.location = "Gym #{trip.photo_album_url} organizer@example.com"
    trip.description = "https://discord.gg/secret-discord"
    trip.meeting_location_url = "https://example.com/private-meeting"
    trip.class_signup_url = "https://example.com/private-registration"
    calendar = render_calendar(trip).gsub("\r\n ", "")

    %w[secret-invite private-album organizer@example.com secret-discord private-meeting private-registration].each do |secret|
      refute_includes calendar, secret
    end
    assert_includes calendar, "SUMMARY:Climb "
    assert_includes calendar, "LOCATION:Gym "
    refute_includes calendar, "DESCRIPTION:"
  end

  private

  def render_calendar(trip)
    TripCalendar.new([ trip ], url_options: { host: "www.cragmontclimbing.com", protocol: "https" }).render
  end
end
