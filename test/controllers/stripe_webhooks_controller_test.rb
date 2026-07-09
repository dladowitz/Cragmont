require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

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

  test "checkout completed stores Stripe processing fee for campsite signup payment" do
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(
      campsite: campsite,
      user: users(:sam),
      arrival_date: campsite.arrival_date,
      checkout_date: campsite.checkout_date
    )
    payment = signup.payments.create!(
      source: "stripe",
      status: "pending",
      amount_cents: 3000,
      stripe_checkout_session_id: "cs_campsite_fee"
    )

    with_env("STRIPE_SECRET_KEY" => "sk_test_fee") do
      with_stripe_processing_fee(117, payment_intent_id: "pi_campsite_fee") do
        perform_enqueued_jobs do
          post stripe_webhooks_url,
            params: stripe_campsite_checkout_event("checkout.session.completed", payment, payment_intent: "pi_campsite_fee"),
            headers: { "CONTENT_TYPE" => "application/json" }
        end
      end
    end

    assert_response :success
    payment.reload
    assert payment.paid?
    assert_equal "pi_campsite_fee", payment.stripe_payment_intent_id
    assert_equal 117, payment.stripe_processing_fee_cents
    assert_equal 2883, payment.stripe_net_amount_cents
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

  def stripe_campsite_checkout_event(type, payment, payment_intent: nil)
    {
      id: "evt_campsite_payment_#{payment.id}",
      type: type,
      data: {
        object: {
          id: payment.stripe_checkout_session_id,
          object: "checkout.session",
          payment_intent: payment_intent,
          metadata: {
            campsite_signup_payment_id: payment.id.to_s,
            campsite_signup_id: payment.campsite_signup_id.to_s,
            trip_id: payment.campsite_signup.trip_id.to_s
          }
        }
      }
    }.to_json
  end

  def with_stripe_processing_fee(fee_cents, payment_intent_id:)
    original_fetch = StripeProcessingFeeFetcher.method(:fetch)
    StripeProcessingFeeFetcher.define_singleton_method(:fetch) do |stripe_payment_intent_id|
      raise "unexpected PaymentIntent #{stripe_payment_intent_id}" unless stripe_payment_intent_id == payment_intent_id

      fee_cents
    end

    yield
  ensure
    StripeProcessingFeeFetcher.define_singleton_method(:fetch, original_fetch)
  end

  def with_env(values)
    originals = values.keys.index_with { |key| ENV[key] }
    values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    originals.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
