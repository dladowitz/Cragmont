class StripeRefundCreator
  def initialize(payment:, amount_cents:, reason:, initiated_by: "system")
    @payment = payment
    @amount_cents = amount_cents
    @reason = reason
    @initiated_by = initiated_by
  end

  def call
    refund_record = @payment.refunds.create!(
      amount_cents: @amount_cents,
      currency: @payment.currency,
      reason: @reason,
      initiated_by: @initiated_by,
      status: "pending"
    )

    if @payment.stripe_payment_intent_id.blank?
      refund_record.update!(status: "failed", failure_reason: "Missing Stripe payment intent")
      return refund_record
    end

    refund = Stripe::Refund.create(
      payment_intent: @payment.stripe_payment_intent_id,
      amount: @amount_cents,
      metadata: {
        campsite_signup_payment_id: @payment.id,
        campsite_signup_payment_refund_id: refund_record.id
      }
    )

    refund_record.update!(
      status: "succeeded",
      stripe_refund_id: refund.id,
      stripe_status: refund.status,
      refunded_at: Time.current
    )
    @payment.update!(
      refunded_amount_cents: @payment.refunded_amount_cents + @amount_cents
    )
    @payment.complete_refund!
    refund_record
  rescue Stripe::StripeError => error
    refund_record&.update!(status: "failed", failure_reason: error.message)
    refund_record
  end
end
