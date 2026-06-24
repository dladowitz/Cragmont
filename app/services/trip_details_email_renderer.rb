require "uri"

class TripDetailsEmailRenderer
  PLACEHOLDER_PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/

  def initialize(trip:, subject:, body_markdown:)
    @trip = trip
    @subject = subject.to_s
    @body_markdown = body_markdown.to_s
  end

  def rendered_subject
    interpolate(subject).squish
  end

  def rendered_markdown
    interpolate(body_markdown)
  end

  def rendered_html
    ApplicationController.helpers.render_trip_details_email_markdown(rendered_markdown).to_s
  end

  def rendered_text
    rendered_markdown
  end

  def uses_placeholder?(placeholder)
    [ subject, body_markdown ].any? { |content| content.match?(/\{\{\s*#{Regexp.escape(placeholder)}\s*\}\}/) }
  end

  private

  attr_reader :trip, :subject, :body_markdown

  def interpolate(content)
    content.gsub(PLACEHOLDER_PATTERN) do
      placeholder_values.fetch(Regexp.last_match(1), Regexp.last_match(0))
    end
  end

  def placeholder_values
    @placeholder_values ||= {
      "trip_name" => trip.name,
      "trip_location" => trip.location,
      "trip_dates" => trip_dates,
      "trip_dates_short" => trip_dates_short,
      "campgrounds" => campgrounds,
      "trip_page_url" => trip_page_url,
      "campsite_registration_info" => campsite_registration_info,
      "coordinator_name" => coordinator_name,
      "coordinator_email" => coordinator_email,
      "coordinator_phone" => coordinator_phone,
      "group_campfire_info" => group_campfire_info,
      "group_campfire_site" => group_campfire_site,
      "group_fire_night" => group_fire_night,
      "whatsapp_group" => safe_http_url(trip.whatsapp_group) || "Not set",
      "whatsapp_group_url" => safe_http_url(trip.whatsapp_group) || "#",
      "weather_url" => safe_http_url(trip.weather_url) || "Not set",
      "photo_album_url" => safe_http_url(trip.photo_album_url) || "Not set"
    }
  end

  def trip_dates
    "#{trip.start_date.to_fs(:long)} to #{trip.end_date.to_fs(:long)}"
  end

  def trip_dates_short
    if trip.start_date.year == trip.end_date.year && trip.start_date.month == trip.end_date.month
      "#{trip.start_date.strftime('%b %-d')}-#{trip.end_date.strftime('%-d, %Y')}"
    elsif trip.start_date.year == trip.end_date.year
      "#{trip.start_date.strftime('%b %-d')}-#{trip.end_date.strftime('%b %-d, %Y')}"
    else
      "#{trip.start_date.strftime('%b %-d, %Y')}-#{trip.end_date.strftime('%b %-d, %Y')}"
    end
  end

  def campgrounds
    names = trip.campsites.includes(:campground).map { |campsite| campsite.campground.name }.uniq
    names.presence&.to_sentence || "Campsites"
  end

  def trip_page_url
    Rails.application.routes.url_helpers.trip_url(trip, default_url_options)
  end

  def campsite_registration_info
    campsites = trip.campsites.includes(:campground, :registered_by).order(:arrival_date, :site_number)
    return "No campsites have been added yet." if campsites.empty?

    campsites.map do |campsite|
      [
        "**#{campsite.campground.name} #{campsite.site_number}**",
        "**Registered by:** #{campsite.registered_by&.full_name || 'Not set'}",
        "**Registration number:** #{campsite.registration_number.presence || 'Not set'}"
      ].join("\n")
    end.join("\n\n")
  end

  def coordinator_name
    trip.campsite_coordinator&.full_name || "Campsite Coordinator"
  end

  def coordinator_email
    trip.campsite_coordinator&.email.presence || "Not set"
  end

  def coordinator_phone
    trip.campsite_coordinator&.phone.presence || "Not set"
  end

  def group_campfire_info
    if trip.group_campfire_campsite.present? && trip.group_fire_night_planned?
      "We'll have a group campfire at **#{group_campfire_site}** on **#{group_fire_night} evening**."
    elsif trip.group_campfire_campsite.present?
      "We'll have a group campfire at **#{group_campfire_site}**."
    elsif trip.group_fire_night_planned?
      "A group campfire is planned for **#{group_fire_night} evening**. The site is not set yet."
    else
      "No group campfire is planned yet."
    end
  end

  def group_campfire_site
    trip.group_campfire_site_label
  end

  def group_fire_night
    trip.group_fire_night_label
  end

  def default_url_options
    Rails.application.config.action_mailer.default_url_options.presence ||
      Rails.application.routes.default_url_options
  end

  def safe_http_url(value)
    uri = URI.parse(value.to_s)
    return unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
