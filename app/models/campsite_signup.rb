class CampsiteSignup < ApplicationRecord
  MAX_GUESTS_PER_SIGNUP = 2
  STATUSES = %w[pending_payment confirmed waitlisted canceled].freeze
  CAPACITY_HOLDING_STATUSES = %w[pending_payment confirmed].freeze

  belongs_to :trip
  belongs_to :campsite, optional: true
  belongs_to :user
  belongs_to :guest_of_signup,
    class_name: "CampsiteSignup",
    optional: true,
    inverse_of: :guest_signups
  has_many :guest_signups,
    -> { order(:guest_position, :created_at) },
    class_name: "CampsiteSignup",
    foreign_key: :guest_of_signup_id,
    dependent: :destroy,
    inverse_of: :guest_of_signup
  has_many :campsite_signup_minors, dependent: :destroy
  has_many :payments,
    class_name: "CampsiteSignupPayment",
    dependent: :destroy,
    inverse_of: :campsite_signup
  has_one_attached :waiver_document
  has_one_attached :waiver_signature_image

  enum :status, STATUSES.index_with(&:itself), default: "confirmed"
  scope :primary, -> { where(guest_of_signup_id: nil) }
  scope :guests, -> { where.not(guest_of_signup_id: nil) }
  scope :capacity_holding, -> { where(status: CAPACITY_HOLDING_STATUSES) }
  scope :active, -> { where.not(status: "canceled") }

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :campsite, presence: true, if: :capacity_holding?
  validates :user_id,
    uniqueness: {
      scope: :trip_id,
      conditions: -> { active },
      message: "is already signed up for this trip"
    },
    unless: :canceled?
  validates :guest_position, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates_associated :campsite_signup_minors
  validate :minor_limit
  validate :guest_link_is_valid
  validate :guest_limit_for_primary
  validate :campsite_belongs_to_trip
  validate :attendance_dates_within_campsite_dates, if: :capacity_holding?

  before_validation :assign_trip_from_campsite
  before_validation :assign_guest_trip
  before_validation :assign_capacity_status, on: :create

  def guest?
    guest_of_signup_id.present?
  end

  def primary_signup
    guest_of_signup || self
  end

  def includes_minors?
    campsite_signup_minors.any?
  end

  def includes_guests?
    guest_signups.any?
  end

  def public_participant_name
    "#{public_name_with_minors} (#{attendance_date_range})"
  end

  def public_waitlist_name
    summary_parts = []
    summary_parts << "#{campsite_signup_minors.size} #{'minor'.pluralize(campsite_signup_minors.size)}" if includes_minors?
    summary_parts << guest_signups.map { |guest_signup| guest_signup.user.public_name }.to_sentence if includes_guests?

    return user.public_name if summary_parts.empty?

    "#{user.public_name} + #{summary_parts.join(' + ')}"
  end

  def capacity_count
    1 + campsite_signup_minors.select(&:capacity_counted?).size
  end

  def party_capacity_count
    return capacity_count if guest?

    capacity_count + guest_signups.sum(&:capacity_count)
  end

  def uncounted_minor_count
    campsite_signup_minors.select(&:uncounted_for_capacity?).size
  end

  def night_count
    return 0 if arrival_date.blank? || checkout_date.blank?

    (checkout_date - arrival_date).to_i
  end

  def attendance_date_range
    return "Not chosen yet" if arrival_date.blank? || checkout_date.blank?

    "#{format_attendance_date(arrival_date)}-#{format_attendance_date(checkout_date)}"
  end

  def compact_attendance_date_range
    return "Not chosen yet" if arrival_date.blank? || checkout_date.blank?

    "#{arrival_date.strftime('%-m/%-d')}-#{checkout_date.strftime('%-m/%-d')}"
  end

  def public_minor_age_summary(age_limit: SiteSetting.current.uncounted_minor_age_limit)
    return "None" unless includes_minors?

    under_count = campsite_signup_minors.count { |minor| minor.age.to_i < age_limit }
    over_count = campsite_signup_minors.size - under_count
    summary_parts = []
    summary_parts << "#{under_count} under #{age_limit}yrs" if under_count.positive?
    summary_parts << "#{over_count} over #{age_limit}yrs" if over_count.positive?
    summary_parts.to_sentence
  end

  def waitlist_eligible?
    waitlist_eligible_at.present?
  end

  def capacity_holding?
    pending_payment? || confirmed?
  end

  def current_payment
    payments.current_first.first
  end

  def payment_status
    current_payment&.status || "unpaid"
  end

  def payment_paid_or_settled?
    payment = current_payment
    return false if payment.blank?

    payment.paid? || payment.waived? || payment.manual_source?
  end

  def waiver_signed?
    waiver_signed_at.present? && waiver_document.attached?
  end

  def waiver_document_filename
    signed_on = (waiver_signed_at || Time.current).strftime("%Y-%m-%d")
    [
      signed_on,
      filename_part(user.first_name),
      filename_part(user.last_name),
      filename_part(trip.name),
      filename_part(campsite&.site_number),
      id
    ].join("-") + ".pdf"
  end

  private

  def public_name_with_minors
    return user.public_name unless includes_minors?

    "#{user.public_name} + #{campsite_signup_minors.size} #{'minor'.pluralize(campsite_signup_minors.size)}"
  end

  def filename_part(value)
    value.to_s.strip.gsub(/[^A-Za-z0-9]+/, "-").gsub(/\A-|-+\z/, "").presence || "Unknown"
  end

  def format_attendance_date(date)
    date.strftime("%b %-d")
  end

  def minor_limit
    errors.add(:campsite_signup_minors, "cannot include more than 2 minors") if campsite_signup_minors.size > 2
  end

  def guest_link_is_valid
    return if guest_of_signup.blank?

    if guest_of_signup == self
      errors.add(:guest_of_signup, "cannot be the same signup")
    elsif guest_of_signup.guest?
      errors.add(:guest_of_signup, "must be a primary participant signup")
    end

    return if trip.blank? || guest_of_signup.trip_id.blank? || trip_id == guest_of_signup.trip_id

    errors.add(:guest_of_signup, "must belong to the same trip")
  end

  def guest_limit_for_primary
    return if guest_of_signup.blank?

    existing_guest_count = guest_of_signup.guest_signups.where.not(id: id).count
    return if existing_guest_count < MAX_GUESTS_PER_SIGNUP

    errors.add(:guest_of_signup, "cannot have more than #{MAX_GUESTS_PER_SIGNUP} guests")
  end

  def campsite_belongs_to_trip
    return if campsite.blank? || trip.blank?
    return if campsite.trip_id == trip.id

    errors.add(:campsite, "must belong to the selected trip")
  end

  def attendance_dates_within_campsite_dates
    return if campsite.blank? || arrival_date.blank? || checkout_date.blank?

    if arrival_date < campsite.arrival_date
      errors.add(:arrival_date, "must be on or after the campsite arrival date")
    end

    if checkout_date > campsite.checkout_date
      errors.add(:checkout_date, "must be on or before the campsite checkout date")
    end

    return if arrival_date < checkout_date

    errors.add(:checkout_date, "must be after the arrival date")
  end

  def assign_trip_from_campsite
    self.trip ||= campsite&.trip
  end

  def assign_guest_trip
    self.trip ||= guest_of_signup&.trip
  end

  def assign_capacity_status
    return if campsite.blank?
    return if waitlisted?
    return if pending_payment? || canceled?

    self.status = campsite.direct_signup_available? && campsite.available_participant_capacity >= capacity_count ? "confirmed" : "waitlisted"
  end
end
