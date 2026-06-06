require "test_helper"

class StripeCheckoutSessionCreatorTest < ActiveSupport::TestCase
  setup do
    @original_creator = Rails.application.config.x.stripe_checkout_session_creator
    @original_secret_key = ENV["STRIPE_SECRET_KEY"]
  end

  teardown do
    Rails.application.config.x.stripe_checkout_session_creator = @original_creator
    ENV["STRIPE_SECRET_KEY"] = @original_secret_key
  end

  test "blank creator config falls back to default stripe creator" do
    Rails.application.config.x.stripe_checkout_session_creator = ActiveSupport::OrderedOptions.new
    ENV["STRIPE_SECRET_KEY"] = nil

    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "pending",
      amount_cents: 5000,
      currency: "usd",
      expires_at: 30.minutes.from_now,
      checkout_expires_at: 30.minutes.from_now,
      previous_signup_status: "confirmed"
    )

    StripeCheckoutSessionCreator

    assert_raises(StripeConfigurationError) do
      StripeCheckoutSessionCreator.create(
        payment: payment,
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )
    end
  end
end
