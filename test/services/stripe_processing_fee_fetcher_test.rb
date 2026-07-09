require "test_helper"
require "ostruct"

class StripeProcessingFeeFetcherTest < ActiveSupport::TestCase
  test "fetches the fee from the expanded latest charge balance transaction" do
    retrieve_params = nil
    balance_transaction = OpenStruct.new(fee: 117)
    charge = OpenStruct.new(balance_transaction: balance_transaction)

    with_payment_intent_retrieve(OpenStruct.new(latest_charge: charge)) do |calls|
      with_env("STRIPE_SECRET_KEY" => "sk_test_fee") do
        assert_equal 117, StripeProcessingFeeFetcher.fetch("pi_test_fee")
      end
      retrieve_params = calls.first
    end

    assert_equal(
      {
        id: "pi_test_fee",
        expand: [ "latest_charge.balance_transaction" ]
      },
      retrieve_params
    )
  end

  test "returns nil when Stripe fee data is not available yet" do
    with_payment_intent_retrieve(OpenStruct.new(latest_charge: OpenStruct.new(balance_transaction: nil))) do
      with_env("STRIPE_SECRET_KEY" => "sk_test_fee") do
        assert_nil StripeProcessingFeeFetcher.fetch("pi_test_fee")
      end
    end
  end

  test "skips Stripe when secret key is missing" do
    called = false
    with_payment_intent_retrieve(OpenStruct.new) do |calls|
      with_env("STRIPE_SECRET_KEY" => nil) do
        assert_nil StripeProcessingFeeFetcher.fetch("pi_test_fee")
      end
      called = calls.any?
    end

    assert_not called
  end

  private

  def with_payment_intent_retrieve(payment_intent)
    original_retrieve = Stripe::PaymentIntent.method(:retrieve)
    calls = []
    Stripe::PaymentIntent.define_singleton_method(:retrieve) do |params|
      calls << params
      payment_intent
    end

    yield calls
  ensure
    Stripe::PaymentIntent.define_singleton_method(:retrieve, original_retrieve)
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
