class StripeProcessingFeeSyncJob < ApplicationJob
  class ProcessingFeeUnavailable < StandardError; end

  retry_on ProcessingFeeUnavailable, wait: :polynomially_longer, attempts: 5
  retry_on Stripe::StripeError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(payment_id)
    payment = CampsiteSignupPayment.find(payment_id)
    return unless payment.stripe_source?
    return if payment.stripe_payment_intent_id.blank?
    return if payment.stripe_processing_fee_cents.present?
    return if ENV["STRIPE_SECRET_KEY"].blank?

    fee_cents = StripeProcessingFeeFetcher.fetch(payment.stripe_payment_intent_id)
    raise ProcessingFeeUnavailable, "Stripe processing fee unavailable for PaymentIntent #{payment.stripe_payment_intent_id}" if fee_cents.nil?

    payment.update!(stripe_processing_fee_cents: fee_cents)
  end
end
