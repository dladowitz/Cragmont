require "test_helper"

class TripPaymentRequestMailerTest < ActionMailer::TestCase
  test "request payment uses knot check opener" do
    payment_request = trips(:yosemite).trip_payment_requests.create!(
      first_name: "David",
      last_name: "Ladowitz",
      email: "david@example.com",
      amount_cents: 4200,
      currency: "usd",
      reason: "Extra campsite balance"
    )
    payment_url = "https://example.com/pay"

    mail = TripPaymentRequestMailer.with(
      payment_request: payment_request,
      payment_url: payment_url
    ).request_payment

    assert_equal "Cragmont Yosemite Valley Spring Payment Request", mail.subject
    assert_equal [ "david@example.com" ], mail.to
    assert_includes mail.html_part.body.decoded, "David Ladowitz, double check that knot before leaving the ground."
    assert_includes mail.text_part.body.decoded, "David Ladowitz, double check that knot before leaving the ground."
    assert_includes mail.html_part.body.decoded, payment_url
    assert_includes mail.text_part.body.decoded, "Clip in and pay here: #{payment_url}"
    assert_not_includes mail.html_part.body.decoded, "get stoked"
    assert_not_includes mail.text_part.body.decoded, "get stoked"
  end
end
