class DayTripSignupMinor < ApplicationRecord
  belongs_to :day_trip_signup

  validates :first_name, :last_name, :relationship, presence: true
  validates :age, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 18 }

  def full_name
    "#{first_name} #{last_name}"
  end
end
