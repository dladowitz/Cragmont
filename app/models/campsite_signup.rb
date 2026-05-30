class CampsiteSignup < ApplicationRecord
  STATUSES = %w[confirmed waitlisted].freeze

  belongs_to :trip
  belongs_to :campsite
  belongs_to :user
  has_many :campsite_signup_minors, dependent: :destroy
  has_one_attached :waiver_document
  has_one_attached :waiver_signature_image

  enum :status, STATUSES.index_with(&:itself), default: "confirmed"

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :trip_id, message: "is already signed up for this trip" }
  validates_associated :campsite_signup_minors
  validate :minor_limit
  validate :campsite_belongs_to_trip

  before_validation :assign_trip_from_campsite
  before_validation :assign_capacity_status, on: :create

  def includes_minors?
    campsite_signup_minors.any?
  end

  def public_participant_name
    return user.public_name unless includes_minors?

    "#{user.public_name} + #{campsite_signup_minors.size} #{'minor'.pluralize(campsite_signup_minors.size)}"
  end

  def capacity_count
    1 + campsite_signup_minors.select(&:capacity_counted?).size
  end

  def uncounted_minor_count
    campsite_signup_minors.select(&:uncounted_for_capacity?).size
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

  def filename_part(value)
    value.to_s.strip.gsub(/[^A-Za-z0-9]+/, "-").gsub(/\A-|-+\z/, "").presence || "Unknown"
  end

  def minor_limit
    errors.add(:campsite_signup_minors, "cannot include more than 2 minors") if campsite_signup_minors.size > 2
  end

  def campsite_belongs_to_trip
    return if campsite.blank? || trip.blank?
    return if campsite.trip_id == trip.id

    errors.add(:campsite, "must belong to the selected trip")
  end

  def assign_trip_from_campsite
    self.trip ||= campsite&.trip
  end

  def assign_capacity_status
    return if campsite.blank?

    self.status = campsite.available_participant_capacity >= capacity_count ? "confirmed" : "waitlisted"
  end
end
