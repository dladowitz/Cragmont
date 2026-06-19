require "test_helper"

class WaiverRequestMailerTest < ActionMailer::TestCase
  test "sign request includes waiver link" do
    waiver_url = Rails.application.routes.url_helpers.waiver_request_url(
      users(:sam).signed_id(purpose: :standalone_waiver_request),
      host: "example.com"
    )

    mail = WaiverRequestMailer.with(
      user: users(:sam),
      requested_by: users(:alex),
      waiver_url: waiver_url
    ).sign_request

    assert_equal "Cragmont Waiver Signing Request", mail.subject
    assert_equal [ users(:sam).email ], mail.to
    assert_includes mail.html_part.body.decoded, "Sam Lee, double check that knot before leaving the ground."
    assert_includes mail.html_part.body.decoded, "Alex Rivera sent you a request to sign the Cragmont waiver."
    assert_includes mail.html_part.body.decoded, waiver_url
    assert_includes mail.text_part.body.decoded, "Sam Lee, double check that knot before leaving the ground."
    assert_includes mail.text_part.body.decoded, "You can sign it here: #{waiver_url}"
    assert_not_includes mail.html_part.body.decoded, "Get Stoked"
    assert_not_includes mail.text_part.body.decoded, "Get Stoked"
  end
end
