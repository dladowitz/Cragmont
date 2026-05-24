class User < ApplicationRecord
  has_secure_password validations: false

  has_many :coordinated_trips,
    class_name: "Trip",
    foreign_key: :campsite_coordinator_id,
    dependent: :restrict_with_error,
    inverse_of: :campsite_coordinator
  has_many :trip_signups, dependent: :restrict_with_error
  has_many :signed_up_trips, through: :trip_signups, source: :trip

  normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

  validates :first_name, :last_name, presence: true
  validates :password, presence: true, on: :create
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def public_name
    "#{first_name} #{last_name.to_s.first}."
  end
end
