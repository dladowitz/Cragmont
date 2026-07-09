class StripeProcessingFeeFetcher
  BALANCE_TRANSACTION_EXPANSION = "latest_charge.balance_transaction".freeze

  def self.fetch(payment_intent_id)
    new(payment_intent_id).call
  end

  def initialize(payment_intent_id)
    @payment_intent_id = payment_intent_id
  end

  def call
    return if @payment_intent_id.blank? || ENV["STRIPE_SECRET_KEY"].blank?

    payment_intent = Stripe::PaymentIntent.retrieve(
      id: @payment_intent_id,
      expand: [ BALANCE_TRANSACTION_EXPANSION ]
    )
    processing_fee_cents(payment_intent)
  end

  private

  def processing_fee_cents(payment_intent)
    charge = attribute(payment_intent, :latest_charge)
    balance_transaction = attribute(charge, :balance_transaction)
    fee_cents = attribute(balance_transaction, :fee)

    Integer(fee_cents) if fee_cents.present?
  rescue ArgumentError, TypeError
    nil
  end

  def attribute(object, key)
    return if object.blank?
    return object.public_send(key) if object.respond_to?(key)
    return object[key.to_s] if object.respond_to?(:[]) && object.respond_to?(:key?) && object.key?(key.to_s)
    object[key] if object.respond_to?(:[]) && object.respond_to?(:key?) && object.key?(key)
  end
end
