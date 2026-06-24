class TripDetailsEmailRecipient < ApplicationRecord
  DELIVERY_STATUSES = %w[pending delivered failed].freeze

  belongs_to :trip_details_email
  belongs_to :user, optional: true
  belongs_to :campsite_signup, optional: true

  enum :delivery_status, DELIVERY_STATUSES.index_with(&:itself)

  normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

  validates :recipient_name, :email, :campsite_label, :delivery_status, presence: true
  validates :delivery_status, inclusion: { in: DELIVERY_STATUSES }
end
