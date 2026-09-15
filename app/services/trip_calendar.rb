class TripCalendar
  # Trip forms store local wall-clock times for this California club.
  TIME_ZONE = ActiveSupport::TimeZone["America/Los_Angeles"]

  def initialize(trips, url_options:)
    @trips = trips
    @url_options = url_options
  end

  def render
    lines = [ "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Cragmont//Trips//EN", "CALSCALE:GREGORIAN", "X-WR-CALNAME:Cragmont Events" ]
    @trips.each do |trip|
      privacy = MemberLinkPrivacy.new(urls: [ trip.whatsapp_group, trip.photo_album_url ])
      lines.concat([
        "BEGIN:VEVENT",
        "UID:trip-#{trip.id}@cragmontclimbing.com",
        "DTSTAMP:#{timestamp(trip.updated_at)}",
        "LAST-MODIFIED:#{timestamp(trip.updated_at)}",
        "SUMMARY:#{escape(privacy.redact_text(trip.name))}",
        "LOCATION:#{escape(privacy.redact_text(trip.location))}",
        "URL:#{Rails.application.routes.url_helpers.trip_url(trip, @url_options)}"
      ])
      if trip.single_day_event? && trip.meeting_time.present?
        start_time = local_time(trip.start_date, trip.meeting_time)
        lines << "DTSTART:#{timestamp(start_time)}"
        if trip.end_time.present?
          end_time = local_time(trip.start_date, trip.end_time)
          end_time = local_time(trip.start_date + 1, trip.end_time) if end_time <= start_time
          lines << "DTEND:#{timestamp(end_time)}"
        end
      else
        lines << "DTSTART;VALUE=DATE:#{trip.start_date.strftime('%Y%m%d')}"
        lines << "DTEND;VALUE=DATE:#{(trip.end_date + 1).strftime('%Y%m%d')}"
      end
      lines << "END:VEVENT"
    end
    lines << "END:VCALENDAR"
    lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
  end

  private

  def timestamp(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def local_time(date, time)
    TIME_ZONE.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
  end

  def escape(text)
    text.to_s.gsub(/\r\n|\r|\n|[\\,;]/) { |character| { "\r\n" => '\n', "\r" => '\n', "\n" => '\n' }.fetch(character) { "\\#{character}" } }
  end

  # RFC 5545 limits physical lines to 75 octets, without splitting UTF-8 characters.
  def fold(line)
    lines = [ +"" ]
    line.each_char do |character|
      lines << +" " if lines.last.bytesize + character.bytesize > 75
      lines.last << character
    end
    lines.join("\r\n")
  end
end
