class CampsiteSignupPaymentRefund < ApplicationRecord
  STATUSES = %w[pending succeeded failed].freeze
  SOURCES = %w[stripe].freeze
  INITIATORS = %w[admin participant system].freeze
  REFUND_TYPES = %w[automatic admin_created trip_expense].freeze

  belongs_to :campsite_signup_payment
  belongs_to :refunded_by, class_name: "User", optional: true

  enum :status, STATUSES.index_with(&:itself)
  enum :source, SOURCES.index_with(&:itself), suffix: true
  enum :initiated_by, INITIATORS.index_with(&:itself), suffix: true
  enum :refund_type, REFUND_TYPES.index_with(&:itself), suffix: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :initiated_by, presence: true, inclusion: { in: INITIATORS }
  validates :refund_type, presence: true, inclusion: { in: REFUND_TYPES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true

  scope :succeeded_for_transactions, -> { succeeded }

  def refund_type_label
    refund_type.titleize
  end
end
