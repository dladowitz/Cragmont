class TripReimbursement < ApplicationRecord
  PAYMENT_METHODS = %w[venmo zelle cash check other].freeze

  belongs_to :trip
  belongs_to :recorded_by, class_name: "User", optional: true

  validates :recipient_name, :payment_method, :paid_on, presence: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def amount
    return nil if amount_cents.blank?

    BigDecimal(amount_cents.to_s) / 100
  end

  def amount=(value)
    self.amount_cents = (BigDecimal(value.to_s.presence || "0") * 100).round
  end
end
