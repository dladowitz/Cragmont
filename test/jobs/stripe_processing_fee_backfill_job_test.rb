require "test_helper"

class StripeProcessingFeeBackfillJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "enqueues fee sync jobs for completed Stripe payments missing fees" do
    eligible_paid = create_payment!(status: "paid", stripe_payment_intent_id: "pi_paid")
    eligible_partial = create_payment!(status: "partially_refunded", stripe_payment_intent_id: "pi_partial")
    eligible_refunded = create_payment!(status: "refunded", stripe_payment_intent_id: "pi_refunded")
    create_payment!(status: "pending", stripe_payment_intent_id: "pi_pending")
    create_payment!(status: "paid", stripe_payment_intent_id: "pi_has_fee", stripe_processing_fee_cents: 117)
    create_payment!(status: "paid", stripe_payment_intent_id: nil)
    create_payment!(source: "manual", status: "paid", manual_payment_method: "cash", manual_paid_at: Time.current)

    assert_enqueued_jobs 3, only: StripeProcessingFeeSyncJob do
      assert_equal 3, StripeProcessingFeeBackfillJob.perform_now
    end

    enqueued_payment_ids = enqueued_jobs
      .select { |job| job.fetch(:job) == StripeProcessingFeeSyncJob }
      .map { |job| job.fetch(:args).first }

    assert_equal [ eligible_paid.id, eligible_partial.id, eligible_refunded.id ], enqueued_payment_ids
  end

  test "honors limit" do
    create_payment!(status: "paid", stripe_payment_intent_id: "pi_one")
    create_payment!(status: "paid", stripe_payment_intent_id: "pi_two")

    assert_enqueued_jobs 1, only: StripeProcessingFeeSyncJob do
      assert_equal 1, StripeProcessingFeeBackfillJob.perform_now(limit: 1)
    end
  end

  test "can run sync jobs inline" do
    payment = create_payment!(status: "paid", stripe_payment_intent_id: "pi_inline")

    with_stripe_processing_fee(117, payment_intent_id: "pi_inline") do
      with_env("STRIPE_SECRET_KEY" => "sk_test_fee") do
        assert_no_enqueued_jobs only: StripeProcessingFeeSyncJob do
          assert_equal 1, StripeProcessingFeeBackfillJob.perform_now(inline: true)
        end
      end
    end

    assert_equal 117, payment.reload.stripe_processing_fee_cents
  end

  private

  def create_payment!(source: "stripe", status:, **attributes)
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(
      campsite: campsite,
      user: User.create!(
        first_name: "Fee",
        last_name: "Backfill#{SecureRandom.hex(4)}",
        email: "fee-backfill-#{SecureRandom.hex(8)}@example.com",
        password: "password"
      ),
      arrival_date: campsite.arrival_date,
      checkout_date: campsite.checkout_date
    )

    signup.payments.create!(
      {
        source: source,
        status: status,
        amount_cents: 3000,
        paid_at: Time.current
      }.merge(attributes)
    )
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
