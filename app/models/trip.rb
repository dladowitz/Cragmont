class Trip < ApplicationRecord
  STATUSES = %w[draft published archived].freeze

  belongs_to :campsite_coordinator,
    class_name: "User",
    optional: true,
    inverse_of: :coordinated_trips
  has_many :campsites, dependent: :destroy
  has_many :campsite_signups, dependent: :destroy
  has_many :participants, through: :campsite_signups, source: :user

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

  def waitlisted_signups
    campsite_signups.primary.waitlisted
      .joins(:user)
      .includes(:user, :campsite_signup_minors, guest_signups: :user)
      .order(Arel.sql("CASE WHEN users.member THEN 0 ELSE 1 END"), :created_at)
  end

  def waitlist_confirmation_campsites_for(signup)
    return [] unless signup&.waitlist_eligible?

    waitlist_open_campsites_for(signup)
  end

  def mark_next_waitlisted_signup_eligible!
    signup = waitlisted_signups.where(waitlist_eligible_at: nil).detect do |waitlisted_signup|
      waitlist_open_campsites_for(waitlisted_signup).any?
    end

    signup&.update!(waitlist_eligible_at: Time.current)
  end

  private

  def waitlist_open_campsites_for(signup)
    campsites.select { |campsite| campsite.available_for_waitlist_confirmation?(signup) }
  end

  def confirmed_signups_with_minors
    return campsite_signups.select(&:confirmed?) if campsite_signups.loaded?

    campsite_signups.confirmed.includes(:campsite_signup_minors)
  end

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
