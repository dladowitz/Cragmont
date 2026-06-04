class StripeCheckoutSessionCreator
  def self.create(**attributes)
    creator_class = Rails.application.config.x.stripe_checkout_session_creator.presence || self
    creator_class.new(**attributes).call
  end

  def initialize(payment:, success_url:, cancel_url:)
    @payment = payment
    @signup = payment.campsite_signup
    @success_url = success_url
    @cancel_url = cancel_url
  end

  def call
    ensure_configured!

    session = Stripe::Checkout::Session.create(
      mode: "payment",
      payment_method_types: [ "card" ],
      customer_email: @signup.user.email.presence,
      line_items: [ line_item ],
      success_url: @success_url,
      cancel_url: @cancel_url,
      expires_at: @payment.expires_at.to_i,
      metadata: metadata,
      payment_intent_data: {
        metadata: metadata
      }
    )

    @payment.update!(
      stripe_checkout_session_id: session.id,
      checkout_url: session.url,
      expires_at: Time.zone.at(session.expires_at)
    )
    @payment
  end

  private

  def line_item
    {
      quantity: 1,
      price_data: {
        currency: @payment.currency,
        unit_amount: @payment.amount_cents,
        product_data: {
          name: "#{@signup.trip.name} campsite signup",
          description: "#{@signup.campsite.campground.name} site #{@signup.campsite.site_number}"
        }
      }
    }
  end

  def metadata
    {
      campsite_signup_payment_id: @payment.id,
      campsite_signup_id: @signup.id,
      trip_id: @signup.trip_id
    }
  end

  def ensure_configured!
    return if ENV["STRIPE_SECRET_KEY"].present?

    raise StripeConfigurationError, "STRIPE_SECRET_KEY is required to create Stripe Checkout Sessions"
  end
end

class StripeConfigurationError < StandardError; end
