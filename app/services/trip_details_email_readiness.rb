class TripDetailsEmailReadiness
  def initialize(trip_details_email)
    @trip_details_email = trip_details_email
    @trip = trip_details_email.trip
  end

  def recipients
    @recipients ||= TripDetailsEmailRecipientList.call(trip)
  end

  def blocking_issues
    issues = []
    issues << "No confirmed participants are on the sharp end yet." if recipients.empty?
    issues.concat(missing_email_issues)
    issues.concat(missing_campsite_registration_issues) if renderer.uses_placeholder?("campsite_registration_info")
    issues
  end

  def sendable?
    blocking_issues.empty?
  end

  private

  attr_reader :trip_details_email, :trip

  def renderer
    @renderer ||= TripDetailsEmailRenderer.new(
      trip: trip,
      subject: trip_details_email.subject,
      body_markdown: trip_details_email.body_markdown
    )
  end

  def missing_email_issues
    missing = recipients.select { |recipient| recipient.email.blank? }
    return [] if missing.empty?

    [ "These confirmed participants need email addresses before sending: #{missing.map(&:recipient_name).to_sentence}." ]
  end

  def missing_campsite_registration_issues
    missing = trip.campsites.includes(:campground, :registered_by).order(:arrival_date, :site_number).filter_map do |campsite|
      missing_fields = []
      missing_fields << "registered by" if campsite.registered_by.blank?
      missing_fields << "registration number" if campsite.registration_number.blank?
      next if missing_fields.empty?

      "#{campsite.campground.name} site #{campsite.site_number} is missing #{missing_fields.to_sentence}"
    end

    missing.map { |message| "#{message}." }
  end
end
