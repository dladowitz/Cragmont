class Trip < ApplicationRecord
  STATUSES = %w[draft published archived].freeze
  ALMOST_FULL_CAPACITY_THRESHOLD = 0.75

  belongs_to :campsite_coordinator,
    class_name: "User",
    optional: true,
    inverse_of: :coordinated_trips
  has_many :campsites, dependent: :destroy
  has_many :campsite_signups, dependent: :destroy
  has_many :participants, through: :campsite_signups, source: :user
  has_many :trip_payment_requests, dependent: :destroy

  before_destroy :ensure_no_active_signups, prepend: true

  enum :status, STATUSES.index_with(&:itself), default: "draft"

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :published_for_public, -> { active.published.order(start_date: :asc, name: :asc) }
  scope :archived_for_public, -> { active.archived.order(start_date: :desc, name: :asc) }
  scope :visible_for_public, -> { active.where(status: %w[published archived]) }

  validates :name, :location, :start_date, :end_date, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
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
    [ total_participant_capacity - held_capacity_count, 0 ].max
  end

  def held_capacity_count
    capacity_holding_signups_with_minors.sum(&:capacity_count)
  end

  def capacity_full?
    available_participant_capacity.zero?
  end

  def almost_full?
    return false if capacity_full? || total_participant_capacity.zero?

    confirmed_signup_count.to_f / total_participant_capacity >= ALMOST_FULL_CAPACITY_THRESHOLD
  end

  def waitlisted_signups
    campsite_signups.primary.waitlisted
      .joins(:user)
      .includes(:user, :campsite_signup_minors, guest_signups: :user)
      .order(Arel.sql("CASE WHEN users.member THEN 0 ELSE 1 END"), :created_at)
  end

  def delete_blocked_by_participants?
    campsite_signups.active.exists?
  end

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
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

  def ensure_no_active_signups
    return unless delete_blocked_by_participants?

    errors.add(:base, "Cannot delete a trip with participants signed up")
    throw :abort
  end

  def waitlist_open_campsites_for(signup)
    campsites.select { |campsite| campsite.available_for_waitlist_confirmation?(signup) }
  end

  def confirmed_signups_with_minors
    return campsite_signups.select(&:confirmed?) if campsite_signups.loaded?

    campsite_signups.confirmed.includes(:campsite_signup_minors)
  end

  def capacity_holding_signups_with_minors
    return campsite_signups.select(&:capacity_holding?) if campsite_signups.loaded?

    campsite_signups.capacity_holding.includes(:campsite_signup_minors)
  end

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
