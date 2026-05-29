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
    confirmed_capacity_count
  end

  def confirmed_capacity_count
    confirmed_signups_with_minors.sum(&:capacity_count)
  end

  def confirmed_uncounted_minor_count
    confirmed_signups_with_minors.sum(&:uncounted_minor_count)
  end

  def uncounted_minor_age_limit
    SiteSetting.current.uncounted_minor_age_limit
  end

  def available_participant_capacity
    [ total_participant_capacity - confirmed_capacity_count, 0 ].max
  end

  def capacity_full?
    available_participant_capacity.zero?
  end

  def almost_full?
    return false if capacity_full? || total_participant_capacity.zero?

    confirmed_signup_count.to_f / total_participant_capacity >= 0.6
  end

  private

  def confirmed_signups_with_minors
    trip_signups.confirmed.includes(:trip_signup_minors)
  end

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
