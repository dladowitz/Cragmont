class TripPaymentRequestsController < ApplicationController
  before_action :set_payment_request

  def show
    if @payment_request.paid?
      render :show
    elsif @payment_request.canceled?
      render :show
    elsif @payment_request.expired?
      render :show
    elsif params[:stripe_checkout] == "success"
      render :show
    elsif params[:stripe_checkout] == "canceled"
      ensure_checkout_session!
      render :show
    else
      ensure_checkout_session!
      redirect_to verified_stripe_checkout_url(@payment_request.checkout_url), allow_other_host: true
    end
  rescue StripeConfigurationError
    redirect_to trips_path, alert: "Wow, that was a whipper. Payment links are not configured yet."
  end

  private

  def set_payment_request
    @payment_request = TripPaymentRequest.find_signed(params[:token], purpose: :trip_payment_request)
    head :not_found if @payment_request.blank?
  end

  def ensure_checkout_session!
    return if @payment_request.checkout_active?

    payment_request_url = trip_payment_request_url(@payment_request.public_token)
    TripPaymentRequestCheckoutSessionCreator.create(
      payment_request: @payment_request,
      success_url: "#{payment_request_url}?stripe_checkout=success",
      cancel_url: "#{payment_request_url}?stripe_checkout=canceled"
    )
  end

  def verified_stripe_checkout_url(url)
    uri = URI.parse(url.to_s)
    return url if uri.is_a?(URI::HTTPS) && uri.host == "checkout.stripe.com"

    raise StripeConfigurationError, "Stripe Checkout returned an invalid URL"
  rescue URI::InvalidURIError
    raise StripeConfigurationError, "Stripe Checkout returned an invalid URL"
  end
end
