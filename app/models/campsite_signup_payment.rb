class CampsiteSignupPayment < ApplicationRecord
  SOURCES = %w[stripe manual waived].freeze
  STATUSES = %w[pending paid expired refunded partially_refunded waived failed].freeze

  belongs_to :campsite_signup
  belongs_to :created_by, class_name: "User", optional: true
  has_many :refunds,
    class_name: "CampsiteSignupPaymentRefund",
    dependent: :destroy,
    inverse_of: :campsite_signup_payment

  enum :source, SOURCES.index_with(&:itself), suffix: true
  enum :status, STATUSES.index_with(&:itself)

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount_cents, :refunded_amount_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :waived_reason, presence: true, if: :waived?
  validates :manual_payment_method, presence: true, if: :manual_source?
  validate :refunded_amount_not_more_than_amount

  scope :current_first, -> { order(created_at: :desc, id: :desc) }
  scope :completed_for_transactions, -> { where(status: %w[paid waived refunded partially_refunded]) }

  def remaining_refundable_amount_cents
    [ amount_cents - refunded_amount_cents, 0 ].max
  end

  def refundable?
    paid? || partially_refunded?
  end

  def complete_refund!
    if remaining_refundable_amount_cents.zero?
      update!(status: "refunded")
    elsif refunded_amount_cents.positive?
      update!(status: "partially_refunded")
    end
  end

  private

  def refunded_amount_not_more_than_amount
    return if amount_cents.blank? || refunded_amount_cents.blank?
    return if refunded_amount_cents <= amount_cents

    errors.add(:refunded_amount_cents, "cannot exceed amount")
  end
end
