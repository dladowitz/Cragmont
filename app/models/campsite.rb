class Campsite < ApplicationRecord
  belongs_to :trip
  belongs_to :campground

  validates :site_number, :arrival_date, :checkout_date, presence: true
  validates :participant_capacity,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :car_capacity,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :checkout_date_after_arrival_date

  private

  def checkout_date_after_arrival_date
    return if arrival_date.blank? || checkout_date.blank?
    return if checkout_date > arrival_date

    errors.add(:checkout_date, "must be after the arrival date")
  end
end
