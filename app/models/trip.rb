class Trip < ApplicationRecord
  STATUSES = %w[draft published archived].freeze

  belongs_to :campsite_coordinator,
    class_name: "User",
    optional: true,
    inverse_of: :coordinated_trips
  has_many :campsites, dependent: :destroy
  has_many :trip_signups, dependent: :destroy
  has_many :participants, through: :trip_signups, source: :user

  enum :status, STATUSES.index_with(&:itself), default: "draft"

  scope :published_for_public, -> { published.order(start_date: :asc, name: :asc) }

  validates :name, :location, :start_date, :end_date, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :campsite_coordinator, presence: true, if: :published?
  validate :end_date_after_start_date

  def campsite_count
    campsites.size
  end

  def total_participant_capacity
    campsites.loaded? ? campsites.sum(&:participant_capacity) : campsites.sum(:participant_capacity)
  end

  def total_car_capacity
    campsites.loaded? ? campsites.sum(&:car_capacity) : campsites.sum(:car_capacity)
  end

  def confirmed_signup_count
    trip_signups.confirmed.count
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
