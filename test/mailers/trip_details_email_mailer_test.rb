require "test_helper"

class TripDetailsEmailMailerTest < ActionMailer::TestCase
  setup do
    TripDetailsEmailTemplate.ensure_defaults!
    template = TripDetailsEmailTemplate.find_by!(area_key: "yosemite")
    @trip_details_email = trips(:yosemite).create_trip_details_email!(
      trip_details_email_template: template,
      status: "sent",
      subject: "Cragmont Yosemite Trip Details",
      body_markdown: "## Details\n\nOn belay!",
      rendered_html_snapshot: "<h2>Details</h2><p>On belay!</p>",
      rendered_text_snapshot: "## Details\n\nOn belay!",
      template_name_snapshot: "Yosemite",
      template_area_key_snapshot: "yosemite",
      sent_at: Time.current,
      sent_by: users(:alex)
    )
    @recipient = @trip_details_email.trip_details_email_recipients.create!(
      user: users(:sam),
      recipient_name: users(:sam).full_name,
      email: users(:sam).email,
      campsite_label: "Upper Pines site A12"
    )
    @cc_recipient = @trip_details_email.trip_details_email_recipients.create!(
      user: users(:alex),
      recipient_name: users(:alex).full_name,
      email: users(:alex).email,
      campsite_label: "Upper Pines site A13"
    )
  end

  test "details email uses Cragmont layout and puts all participants in the to field" do
    mail = TripDetailsEmailMailer.with(
      trip_details_email: @trip_details_email,
      recipients: [ @recipient, @cc_recipient ]
    ).details

    assert_equal "Cragmont Yosemite Trip Details", mail.subject
    assert_equal [ users(:sam).email, users(:alex).email ], mail.to
    assert_empty Array(mail.cc)
    assert_empty Array(mail.bcc)
    assert_includes mail.html_part.body.decoded, "Cragmont"
    assert_includes mail.html_part.body.decoded, "Climbing Club"
    assert_includes mail.html_part.body.decoded, "<h2>Details</h2>"
    assert_includes mail.text_part.body.decoded, "## Details"
  end
end
