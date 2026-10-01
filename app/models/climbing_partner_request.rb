class ClimbingPartnerRequest < ApplicationRecord
  belongs_to :trip
  belongs_to :user

  validates :user_id, uniqueness: { scope: :trip_id }
  validate :trip_is_camping_trip

  private

  def trip_is_camping_trip
    return if trip.blank? || trip.camping?

    errors.add(:trip, "must be a camping trip")
  end
end
