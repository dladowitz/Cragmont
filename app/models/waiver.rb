class Waiver < ApplicationRecord
  TYPES = %w[annual_adult trip_minor].freeze

  belongs_to :user
  belongs_to :trip, optional: true
  belongs_to :campsite_signup, optional: true

  has_one_attached :document
  has_one_attached :signature_image

  enum :waiver_type, TYPES.index_with(&:itself)

  scope :signed, -> { where.not(waiver_signed_at: nil) }
  scope :current_first, -> { order(waiver_signed_at: :desc, id: :desc) }
  scope :for_year, ->(year) { where(waiver_year: year) }

  validates :waiver_year, presence: true, numericality: { only_integer: true }
  validates :waiver_type, presence: true, inclusion: { in: TYPES }
  validates :waiver_signed_at, presence: true

  def current?
    document.attached? && waiver_signed_at.present?
  end

  def document_filename
    signed_on = (waiver_signed_at || Time.current).strftime("%Y-%m-%d")
    parts = [
      signed_on,
      filename_part(user.first_name),
      filename_part(user.last_name),
      waiver_year,
      waiver_type.tr("_", "-")
    ]
    parts << filename_part(trip.name) if trip.present?
    parts << id
    parts.join("-") + ".pdf"
  end

  def display_type
    trip_minor? ? "Trip with minors" : "Annual adult"
  end

  def minors_summary
    return "None" unless campsite_signup&.includes_minors?

    campsite_signup.campsite_signup_minors.map(&:full_name).to_sentence
  end

  private

  def filename_part(value)
    value.to_s.strip.gsub(/[^A-Za-z0-9]+/, "-").gsub(/\A-|-+\z/, "").presence || "Unknown"
  end
end
