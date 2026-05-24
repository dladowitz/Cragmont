class Trip < ApplicationRecord
  STATUSES = %w[draft published archived].freeze

  has_many :campsites, dependent: :destroy

  enum :status, STATUSES.index_with(&:itself), default: "draft"

  validates :name, :location, :start_date, :end_date, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :end_date_after_start_date

  def campsite_count
    campsites.size
  end

  def total_participant_capacity
    campsites.sum(:participant_capacity)
  end

  def total_car_capacity
    campsites.sum(:car_capacity)
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
