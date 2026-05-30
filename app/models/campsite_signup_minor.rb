class CampsiteSignupMinor < ApplicationRecord
  belongs_to :campsite_signup

  validates :first_name, :last_name, :relationship, presence: true
  validates :age, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 18 }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def capacity_counted?
    age.to_i >= SiteSetting.current.uncounted_minor_age_limit
  end

  def uncounted_for_capacity?
    age.to_i < SiteSetting.current.uncounted_minor_age_limit
  end
end
