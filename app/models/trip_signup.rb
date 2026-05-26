class TripSignup < ApplicationRecord
  STATUSES = %w[confirmed waitlisted].freeze

  belongs_to :trip
  belongs_to :user
  has_one_attached :waiver_document
  has_one_attached :waiver_signature_image

  enum :status, STATUSES.index_with(&:itself), default: "confirmed"

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :trip_id, message: "is already signed up for this trip" }

  before_validation :assign_capacity_status, on: :create

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
      id
    ].join("-") + ".pdf"
  end

  private

  def filename_part(value)
    value.to_s.strip.gsub(/[^A-Za-z0-9]+/, "-").gsub(/\A-|-+\z/, "").presence || "Unknown"
  end

  def assign_capacity_status
    return if trip.blank?

    self.status = trip.confirmed_signup_count < trip.total_participant_capacity ? "confirmed" : "waitlisted"
  end
end
