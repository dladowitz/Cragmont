class TripPaymentRequest < ApplicationRecord
  STATUSES = %w[pending paid canceled].freeze

  belongs_to :trip
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :canceled_by, class_name: "User", optional: true

  enum :status, STATUSES.index_with(&:itself), default: "pending"

  normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

  validates :first_name, :last_name, :email, :reason, :currency, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  before_validation :set_default_expiration, on: :create

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def amount
    return nil if amount_cents.blank?

    BigDecimal(amount_cents.to_s) / 100
  end

  def amount=(value)
    self.amount_cents = (BigDecimal(value.to_s.presence || "0") * 100).round
  end

  def public_token
    signed_id(purpose: :trip_payment_request)
  end

  def admin_modal_token
    signed_id(purpose: :admin_trip_payment_request)
  end

  def checkout_active?
    checkout_url.present? && checkout_expires_at.present? && checkout_expires_at.future?
  end

  def mark_paid!(stripe_checkout_session_id:, stripe_payment_intent_id: nil)
    update!(
      status: "paid",
      stripe_checkout_session_id: stripe_checkout_session_id,
      stripe_payment_intent_id: stripe_payment_intent_id,
      paid_at: Time.current
    )
  end

  def clear_expired_checkout!(stripe_checkout_session_id:)
    return unless pending?
    return if self.stripe_checkout_session_id.present? && self.stripe_checkout_session_id != stripe_checkout_session_id

    update!(
      checkout_url: nil,
      stripe_checkout_session_id: nil,
      checkout_expires_at: nil
    )
  end

  def cancel!(canceled_by:)
    update!(
      status: "canceled",
      canceled_by: canceled_by,
      canceled_at: Time.current
    )
  end

  def expired?
    pending? && expires_at.present? && expires_at.past?
  end

  private

  def set_default_expiration
    self.expires_at ||= 30.days.from_now
  end
end
