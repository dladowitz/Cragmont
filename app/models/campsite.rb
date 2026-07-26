class Campsite < ApplicationRecord
  belongs_to :trip
  belongs_to :campground
  belongs_to :registered_by, class_name: "User", optional: true, inverse_of: :registered_campsites
  belongs_to :registration_reimbursed_by, class_name: "User", optional: true
  belongs_to :registration_reimbursement_recorded_by, class_name: "User", optional: true
  has_one :group_campfire_trip,
    class_name: "Trip",
    foreign_key: :group_campfire_campsite_id,
    dependent: :nullify,
    inverse_of: :group_campfire_campsite
  has_many :campsite_signups
  has_many :participants, through: :campsite_signups, source: :user
  has_many :parking_spots,
    -> { ordered },
    class_name: "CampsiteParkingSpot",
    inverse_of: :campsite

  REIMBURSEMENT_METHODS = {
    "venmo" => "Venmo",
    "stripe" => "Stripe",
    "other" => "Other"
  }.freeze

  before_destroy :ensure_no_active_signups
  before_destroy :detach_canceled_signups

  validates :site_number, :arrival_date, :checkout_date, presence: true
  validates :participant_capacity,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :car_capacity,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :registration_fee_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :registration_reimbursement_method, inclusion: { in: REIMBURSEMENT_METHODS.keys }, allow_blank: true
  validate :reimbursement_details_complete
  validate :car_capacity_can_cover_assigned_parking_spots
  validate :checkout_date_after_arrival_date
  validate :reservation_dates_within_trip_dates

  after_create :sync_parking_spots!
  after_update :sync_parking_spots!, if: :saved_change_to_car_capacity?

  def registration_fee
    BigDecimal(registration_fee_cents.to_i.to_s) / 100
  end

  def registration_fee=(amount)
    normalized_amount = amount.to_s.delete("$,").strip
    self.registration_fee_cents = normalized_amount.present? ? (BigDecimal(normalized_amount) * 100).round : 0
  end

  def registration_reimbursed?
    registration_reimbursed_at.present?
  end

  def registration_reimbursement_method_label
    REIMBURSEMENT_METHODS.fetch(registration_reimbursement_method, "None")
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

  def assigned_parking_spot_count
    parking_spots.select(&:assigned?).size
  end

  def first_come_first_serve_parking_spot_count
    parking_spots.select(&:first_come_first_serve?).size
  end

  def configured_parking_spot_count
    parking_spots.reject(&:unassigned?).size
  end

  def sync_parking_spots!
    return if car_capacity.blank?

    current_count = parking_spots.reload.size
    target_count = car_capacity.to_i

    if current_count < target_count
      ((current_count + 1)..target_count).each do |position|
        parking_spots.create!(position: position)
      end
    elsif current_count > target_count
      parking_spots.where("position > ?", target_count).where.not(status: "assigned").destroy_all
    end
  end

  def delete_blocked_by_participants?
    campsite_signups.active.exists?
  end

  private

  def ensure_no_active_signups
    return unless delete_blocked_by_participants?

    errors.add(:base, "Cannot delete campsite with participants signed up")
    throw :abort
  end

  def detach_canceled_signups
    campsite_signups.canceled.update_all(campsite_id: nil, updated_at: Time.current)
  end

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

  def reimbursement_details_complete
    return unless reimbursement_started?

    errors.add(:registration_reimbursed_at, "can't be blank") if registration_reimbursed_at.blank?
    errors.add(:registration_reimbursed_by, "must be selected") if registration_reimbursed_by.blank?
    errors.add(:registration_reimbursement_method, "must be selected") if registration_reimbursement_method.blank?
    errors.add(:registration_reimbursement_recorded_by, "must be selected") if registration_reimbursement_recorded_by.blank?
  end

  def reimbursement_started?
    registration_reimbursed_at.present? ||
      registration_reimbursed_by.present? ||
      registration_reimbursement_method.present? ||
      registration_reimbursement_recorded_by.present? ||
      registration_reimbursement_notes.present?
  end

  def car_capacity_can_cover_assigned_parking_spots
    return if car_capacity.blank? || new_record?

    assigned_position = parking_spots.where(status: "assigned").maximum(:position)
    return if assigned_position.blank? || assigned_position <= car_capacity

    errors.add(:car_capacity, "cannot be below assigned parking spots")
  end
end
