require "test_helper"

class TripPaymentRequestsControllerTest < ActionDispatch::IntegrationTest
  FakeTripPaymentRequestCheckoutSessionCreator = Struct.new(:payment_request, :success_url, :cancel_url, keyword_init: true) do
    def call
      payment_request.update!(
        stripe_checkout_session_id: "cs_public_trip_request_#{payment_request.id}",
        checkout_url: "https://checkout.stripe.com/c/pay/public-trip-request-#{payment_request.id}",
        checkout_expires_at: 24.hours.from_now
      )
      payment_request
    end
  end

  test "pending request redirects to Stripe Checkout" do
    payment_request = create_payment_request!(
      checkout_url: "https://checkout.stripe.com/c/pay/current",
      checkout_expires_at: 1.hour.from_now
    )

    get trip_payment_request_url(payment_request.public_token)

    assert_redirected_to "https://checkout.stripe.com/c/pay/current"
  end

  test "expired checkout session is regenerated" do
    payment_request = create_payment_request!(
      stripe_checkout_session_id: "cs_expired",
      checkout_url: "https://checkout.stripe.com/c/pay/expired",
      checkout_expires_at: 1.hour.ago
    )

    with_fake_trip_payment_request_checkout do
      get trip_payment_request_url(payment_request.public_token)
    end

    assert_redirected_to "https://checkout.stripe.com/c/pay/public-trip-request-#{payment_request.id}"
    assert_equal "cs_public_trip_request_#{payment_request.id}", payment_request.reload.stripe_checkout_session_id
  end

  test "paid request shows paid message" do
    payment_request = create_payment_request!(status: "paid", paid_at: Time.current)

    get trip_payment_request_url(payment_request.public_token)

    assert_response :success
    assert_select "h1", text: "On belay! Payment received."
  end

  test "canceled request does not redirect to Stripe" do
    payment_request = create_payment_request!(status: "canceled", canceled_at: Time.current)

    get trip_payment_request_url(payment_request.public_token)

    assert_response :success
    assert_select "h1", text: "This payment request is no longer active."
  end

  test "expired pending request does not redirect to Stripe" do
    payment_request = create_payment_request!(
      expires_at: 1.hour.ago,
      checkout_url: "https://checkout.stripe.com/c/pay/current",
      checkout_expires_at: 1.hour.from_now
    )

    get trip_payment_request_url(payment_request.public_token)

    assert_response :success
    assert_select "h1", text: "This payment request is no longer active."
    assert_select "p", text: "This link has expired. Reach out to the trip team if you need a fresh payment link."
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

  def with_fake_trip_payment_request_checkout
    original_creator = Rails.application.config.x.trip_payment_request_checkout_session_creator
    Rails.application.config.x.trip_payment_request_checkout_session_creator = FakeTripPaymentRequestCheckoutSessionCreator
    yield
  ensure
    Rails.application.config.x.trip_payment_request_checkout_session_creator = original_creator
  end
end
