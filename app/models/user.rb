require "digest"
require "securerandom"

class User < ApplicationRecord
  DEFAULT_GUEST_PASSWORD = "Cragmont!".freeze
  PASSWORD_RESET_EXPIRATION = 48.hours

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
  before_save :clear_password_reset_token, if: :password_digest_changed?

  def self.find_by_password_reset_token(token)
    return if token.blank?

    user = find_by(password_reset_token_digest: password_reset_token_digest(token))
    return if user.blank?

    user if user.valid_password_reset_token?(token)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def public_name
    "#{first_name} #{last_name.to_s.first}."
  end

  def generate_password_reset_token!
    token = SecureRandom.urlsafe_base64(32)

    update!(
      password_reset_token_digest: self.class.password_reset_token_digest(token),
      password_reset_sent_at: Time.current
    )

    token
  end

  def valid_password_reset_token?(token)
    return false if token.blank? || password_reset_token_digest.blank? || password_reset_sent_at.blank?
    return false if password_reset_sent_at < PASSWORD_RESET_EXPIRATION.ago

    ActiveSupport::SecurityUtils.secure_compare(
      password_reset_token_digest,
      self.class.password_reset_token_digest(token)
    )
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

  def self.password_reset_token_digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def clear_default_password_after_password_change
    self.default_password = false unless new_record?
  end

  def clear_password_reset_token
    self.password_reset_token_digest = nil
    self.password_reset_sent_at = nil
  end
end
