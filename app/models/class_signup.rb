class ClassSignup < ApplicationRecord
  STATUSES = %w[confirmed canceled].freeze

  belongs_to :trip
  belongs_to :user

  enum :status, STATUSES.index_with(&:itself), default: "confirmed"
  scope :active, -> { where.not(status: "canceled") }

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id,
    uniqueness: {
      scope: :trip_id,
      conditions: -> { active },
      message: "is already signed up for this class"
    },
    unless: :canceled?
  validate :trip_is_class

  def public_participant_name
    user.public_name
  end

  private

  def trip_is_class
    return if trip&.class_trip?

    errors.add(:trip, "must be a class")
  end
end
