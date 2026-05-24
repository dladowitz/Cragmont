class User < ApplicationRecord
  has_many :coordinated_trips,
    class_name: "Trip",
    foreign_key: :campsite_coordinator_id,
    dependent: :restrict_with_error,
    inverse_of: :campsite_coordinator

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :first_name, :last_name, presence: true
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
