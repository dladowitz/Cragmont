class CampsiteSignupPaymentRefund < ApplicationRecord
  STATUSES = %w[pending succeeded failed].freeze
  SOURCES = %w[stripe].freeze

  belongs_to :campsite_signup_payment

  enum :status, STATUSES.index_with(&:itself)
  enum :source, SOURCES.index_with(&:itself), suffix: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true
end
