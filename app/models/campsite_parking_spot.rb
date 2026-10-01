class CampsiteParkingSpot < ApplicationRecord
  STATUSES = %w[unassigned assigned first_come_first_serve].freeze
  STATUS_LABELS = {
    "unassigned" => "TBD",
    "assigned" => "Assigned",
    "first_come_first_serve" => "First Come First Serve"
  }.freeze

  belongs_to :campsite
  belongs_to :assigned_campsite_signup,
    class_name: "CampsiteSignup",
    optional: true,
    inverse_of: :assigned_parking_spot

  enum :status, STATUSES.index_with(&:itself), default: "unassigned"

  before_validation :clear_assignment_unless_assigned

  validates :position,
    presence: true,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :campsite_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :assigned_signup_is_confirmed_on_trip
  validate :assigned_signup_is_not_already_parked

  scope :configured, -> { where.not(status: "unassigned") }
  scope :ordered, -> { order(:position) }

  def spot_label
    "Spot #{position}"
  end

  def status_label
    STATUS_LABELS.fetch(status)
  end

  def public_assignment_label
    return assigned_campsite_signup.user.public_name if assigned? && assigned_campsite_signup.present?

    status_label
  end

  private

  def clear_assignment_unless_assigned
    self.assigned_campsite_signup = nil unless assigned?
  end

  def assigned_signup_is_confirmed_on_trip
    return unless assigned?

    if assigned_campsite_signup.blank?
      errors.add(:assigned_campsite_signup, "must be selected")
      return
    end

    unless assigned_campsite_signup.confirmed?
      errors.add(:assigned_campsite_signup, "must be a confirmed participant")
    end

    return if campsite.blank? || assigned_campsite_signup.trip_id == campsite.trip_id

    errors.add(:assigned_campsite_signup, "must belong to this trip")
  end

  def assigned_signup_is_not_already_parked
    return unless assigned? && assigned_campsite_signup_id.present?

    duplicate = self.class.where(assigned_campsite_signup_id: assigned_campsite_signup_id).where.not(id: id).exists?
    return unless duplicate

    errors.add(:base, "The participant is already assigned to a parking spot")
  end
end
