require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "checkout completed marks trip payment request paid" do
    payment_request = create_payment_request!(stripe_checkout_session_id: "cs_trip_request")

    post stripe_webhooks_url,
      params: stripe_checkout_event("checkout.session.completed", payment_request, payment_intent: "pi_trip_request"),
      headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :success
    payment_request.reload
    assert_equal "paid", payment_request.status
    assert_equal "pi_trip_request", payment_request.stripe_payment_intent_id
    assert_not_nil payment_request.paid_at
  end

  test "checkout expired clears stale checkout but leaves trip payment request pending" do
    payment_request = create_payment_request!(
      stripe_checkout_session_id: "cs_trip_request_expired",
      checkout_url: "https://checkout.stripe.com/c/pay/expired",
      checkout_expires_at: 1.hour.from_now
    )

    post stripe_webhooks_url,
      params: stripe_checkout_event("checkout.session.expired", payment_request),
      headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :success
    payment_request.reload
    assert_equal "pending", payment_request.status
    assert_nil payment_request.stripe_checkout_session_id
    assert_nil payment_request.checkout_url
    assert_nil payment_request.checkout_expires_at
    assert_not_nil payment_request.expires_at
  end

  private

  def create_payment_request!(**attributes)
    trips(:yosemite).trip_payment_requests.create!(
      {
        first_name: "Cam",
        last_name: "Stone",
        email: "cam@example.com",
        amount_cents: 4250,
        reason: "Extra permit"
      }.merge(attributes)
    )
  end

  def stripe_checkout_event(type, payment_request, payment_intent: nil)
    {
      id: "evt_trip_payment_request_#{payment_request.id}",
      type: type,
      data: {
        object: {
          id: payment_request.stripe_checkout_session_id,
          object: "checkout.session",
          payment_intent: payment_intent,
          metadata: {
            trip_payment_request_id: payment_request.id.to_s,
            trip_id: payment_request.trip_id.to_s
          }
        }
      }
    }.to_json
  end
end
