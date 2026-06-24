class TripDetailsEmailDelivery
  class AlreadySentError < StandardError; end
  class BlockingIssuesError < StandardError
    attr_reader :issues

    def initialize(issues)
      @issues = issues
      super(issues.to_sentence)
    end
  end

  def self.deliver!(trip_details_email:, sent_by:)
    new(trip_details_email: trip_details_email, sent_by: sent_by).deliver!
  end

  def initialize(trip_details_email:, sent_by:)
    @trip_details_email = trip_details_email
    @sent_by = sent_by
  end

  def deliver!
    recipients = snapshot_email_and_recipients!
    deliver_to_recipients(recipients)
    trip_details_email
  end

  private

  attr_reader :trip_details_email, :sent_by

  def snapshot_email_and_recipients!
    readiness = TripDetailsEmailReadiness.new(trip_details_email)
    issues = readiness.blocking_issues
    raise BlockingIssuesError.new(issues) if issues.any?

    renderer = TripDetailsEmailRenderer.new(
      trip: trip_details_email.trip,
      subject: trip_details_email.subject,
      body_markdown: trip_details_email.body_markdown
    )

    TripDetailsEmail.transaction do
      trip_details_email.lock!
      raise AlreadySentError, "This trip details email has already been sent." if trip_details_email.sent?

      trip_details_email.trip_details_email_recipients.destroy_all
      trip_details_email.update!(
        status: "sent",
        subject: renderer.rendered_subject,
        body_markdown: renderer.rendered_markdown,
        rendered_html_snapshot: renderer.rendered_html,
        rendered_text_snapshot: renderer.rendered_text,
        template_name_snapshot: trip_details_email.trip_details_email_template.name,
        template_area_key_snapshot: trip_details_email.trip_details_email_template.area_key,
        sent_at: Time.current,
        sent_by: sent_by
      )

      readiness.recipients.map do |recipient|
        trip_details_email.trip_details_email_recipients.create!(
          user: recipient.user,
          campsite_signup: recipient.signup,
          recipient_name: recipient.recipient_name,
          email: recipient.email,
          campsite_label: recipient.campsite_label
        )
      end
    end
  end

  def deliver_to_recipients(recipients)
    recipients.each do |recipient|
      TripDetailsEmailMailer.with(
        trip_details_email: trip_details_email,
        recipient: recipient
      ).details.deliver_now
      recipient.update!(delivery_status: "delivered", delivered_at: Time.current, error_message: nil)
    rescue StandardError => error
      recipient.update!(delivery_status: "failed", error_message: error.message)
    end
  end
end
