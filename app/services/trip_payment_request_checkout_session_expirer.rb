class TripPaymentRequestCheckoutSessionExpirer
  def self.expire(**attributes)
    expirer_class = Rails.application.config.x.trip_payment_request_checkout_session_expirer.presence || self
    expirer_class.new(**attributes).call
  end

  def initialize(payment_request:)
    @payment_request = payment_request
  end

  def call
    return @payment_request if @payment_request.stripe_checkout_session_id.blank?

    ensure_configured!
    Stripe::Checkout::Session.expire(@payment_request.stripe_checkout_session_id)
    @payment_request
  rescue Stripe::InvalidRequestError => error
    raise unless error.message.to_s.match?(/expired|No such checkout.session/i)

    @payment_request
  end

  private

  def ensure_configured!
    return if ENV["STRIPE_SECRET_KEY"].present?

    raise StripeConfigurationError, "STRIPE_SECRET_KEY is required to expire Stripe Checkout Sessions"
  end
end

class StripeConfigurationError < StandardError; end unless defined?(StripeConfigurationError)
