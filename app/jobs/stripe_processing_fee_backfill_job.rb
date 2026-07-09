class StripeProcessingFeeBackfillJob < ApplicationJob
  COMPLETED_STATUSES = %w[paid partially_refunded refunded].freeze

  def perform(limit: nil, inline: false)
    enqueued_count = 0

    payments_for_backfill(limit: limit).find_each do |payment|
      if inline
        StripeProcessingFeeSyncJob.perform_now(payment.id)
      else
        StripeProcessingFeeSyncJob.perform_later(payment.id)
      end
      enqueued_count += 1
    end

    action = inline ? "Ran" : "Enqueued"
    Rails.logger.info("#{action} #{enqueued_count} Stripe processing fee sync jobs")
    enqueued_count
  end

  private

  def payments_for_backfill(limit:)
    scope = CampsiteSignupPayment
      .where(source: "stripe", status: COMPLETED_STATUSES, stripe_processing_fee_cents: nil)
      .where.not(stripe_payment_intent_id: [ nil, "" ])
      .order(:id)

    limit.present? ? scope.limit(limit) : scope
  end
end
