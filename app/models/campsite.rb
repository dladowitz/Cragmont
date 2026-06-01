class Campsite < ApplicationRecord
  belongs_to :trip
  belongs_to :campground
  belongs_to :registered_by, class_name: "User", optional: true, inverse_of: :registered_campsites
  has_many :campsite_signups, dependent: :restrict_with_error
  has_many :participants, through: :campsite_signups, source: :user

  validates :site_number, :arrival_date, :checkout_date, presence: true
  validates :participant_capacity,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :car_capacity,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :checkout_date_after_arrival_date
  validate :reservation_dates_within_trip_dates

  def confirmed_signup_count
    confirmed_capacity_count
  end

  def confirmed_capacity_count
    confirmed_signups_with_minors.sum(&:capacity_count)
  end

  def confirmed_uncounted_minor_count
    confirmed_signups_with_minors.sum(&:uncounted_minor_count)
  end

  def available_participant_capacity
    [ participant_capacity - held_capacity_count, 0 ].max
  end

  def held_capacity_count
    capacity_holding_signups_with_minors.sum(&:capacity_count)
  end

  def capacity_full?
    available_participant_capacity.zero?
  end

  def signups_locked?
    signups_locked_at.present?
  end

  def direct_signup_available?
    !signups_locked? && available_participant_capacity.positive?
  end

  def waitlist_signup_required?
    signups_locked? || capacity_full?
  end

  def lock_signups!
    update!(signups_locked_at: Time.current) if signups_locked_at.blank?
  end

  def lock_signups_if_full!
    lock_signups! if capacity_full?
  end

  def available_for_waitlist_confirmation?(signup)
    available_participant_capacity >= signup.party_capacity_count
  end

  def confirmed_signups
    campsite_signups.confirmed.includes(:user, :campsite_signup_minors).order(created_at: :asc)
  end

  def waitlisted_signups
    campsite_signups.waitlisted.includes(:user, :campsite_signup_minors).order(created_at: :asc)
  end

  def pending_payment_signups
    campsite_signups.pending_payment.includes(:user, :campsite_signup_minors).order(created_at: :asc)
  end

  private

  def confirmed_signups_with_minors
    return campsite_signups.select(&:confirmed?) if campsite_signups.loaded?

    campsite_signups.confirmed.includes(:campsite_signup_minors)
  end

  def capacity_holding_signups_with_minors
    return campsite_signups.select(&:capacity_holding?) if campsite_signups.loaded?

    campsite_signups.capacity_holding.includes(:campsite_signup_minors)
  end

  def checkout_date_after_arrival_date
    return if arrival_date.blank? || checkout_date.blank?
    return if checkout_date > arrival_date

    errors.add(:checkout_date, "must be after the arrival date")
  end

  def reservation_dates_within_trip_dates
    return if trip.blank?

    validate_trip_date_range(:arrival_date, arrival_date)
    validate_trip_date_range(:checkout_date, checkout_date)
  end

  def validate_trip_date_range(attribute, value)
    return if value.blank? || trip.start_date.blank? || trip.end_date.blank?
    return if value.between?(trip.start_date, trip.end_date)

    errors.add(attribute, "must be within the trip dates")
  end
end
