class User < ApplicationRecord
  DEFAULT_GUEST_PASSWORD = "Cragmont!".freeze

  has_secure_password validations: false

  has_many :coordinated_trips,
    class_name: "Trip",
    foreign_key: :campsite_coordinator_id,
    dependent: :restrict_with_error,
    inverse_of: :campsite_coordinator
  has_many :registered_campsites,
    class_name: "Campsite",
    foreign_key: :registered_by_id,
    dependent: :nullify,
    inverse_of: :registered_by
  has_many :campsite_signups, dependent: :restrict_with_error
  has_many :signed_up_trips, -> { distinct }, through: :campsite_signups, source: :trip

  normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

  validates :first_name, :last_name, presence: true
  validates :password, presence: true, on: :create
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true

  before_save :clear_default_password_after_password_change, if: :password_digest_changed?

  def full_name
    "#{first_name} #{last_name}"
  end

  def public_name
    "#{first_name} #{last_name.to_s.first}."
  end

  def destroy_account_with_history!
    transaction do
      coordinated_trips.update_all(campsite_coordinator_id: nil, updated_at: Time.current)
      registered_campsites.update_all(registered_by_id: nil, updated_at: Time.current)
      campsite_signups.destroy_all
      destroy!
    end
  end

  private

  def clear_default_password_after_password_change
    self.default_password = false unless new_record?
  end
end
