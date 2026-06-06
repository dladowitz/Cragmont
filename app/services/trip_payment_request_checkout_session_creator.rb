class TripPaymentRequestCheckoutSessionCreator
  def self.create(**attributes)
    creator_class = Rails.application.config.x.trip_payment_request_checkout_session_creator.presence || self
    creator_class.new(**attributes).call
  end

  def initialize(payment_request:, success_url:, cancel_url:)
    @payment_request = payment_request
    @success_url = success_url
    @cancel_url = cancel_url
  end

  def call
    ensure_configured!

    session = Stripe::Checkout::Session.create(
      mode: "payment",
      customer_email: @payment_request.email,
      line_items: [ line_item ],
      success_url: @success_url,
      cancel_url: @cancel_url,
      metadata: metadata,
      payment_intent_data: {
        metadata: metadata
      }
    )

    @payment_request.update!(
      stripe_checkout_session_id: session.id,
      checkout_url: session.url,
      checkout_expires_at: Time.zone.at(session.expires_at)
    )
    @payment_request
  end

  private

  def line_item
    {
      quantity: 1,
      price_data: {
        currency: @payment_request.currency,
        unit_amount: @payment_request.amount_cents,
        product_data: {
          name: "#{@payment_request.trip.name} payment request",
          description: @payment_request.reason
        }
      }
    }
  end

  def metadata
    {
      trip_payment_request_id: @payment_request.id,
      trip_id: @payment_request.trip_id
    }
  end

  def ensure_configured!
    return if ENV["STRIPE_SECRET_KEY"].present?

    raise StripeConfigurationError, "STRIPE_SECRET_KEY is required to create Stripe Checkout Sessions"
  end
end

class StripeConfigurationError < StandardError; end unless defined?(StripeConfigurationError)
