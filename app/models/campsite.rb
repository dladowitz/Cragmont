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
  validate :reservation_dates_within_trip_dates

  private

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
