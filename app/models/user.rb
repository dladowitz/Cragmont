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
  has_many :day_trip_signups, dependent: :restrict_with_error
  has_many :class_signups, dependent: :restrict_with_error
  has_many :waivers, dependent: :destroy
  has_many :help_requests, dependent: :nullify
  has_many :help_request_replies, dependent: :restrict_with_error
  has_many :issued_refunds,
    class_name: "CampsiteSignupPaymentRefund",
    foreign_key: :refunded_by_id,
    dependent: :nullify,
    inverse_of: :refunded_by
  has_many :created_trip_payment_requests,
    class_name: "TripPaymentRequest",
    foreign_key: :created_by_id,
    dependent: :nullify,
    inverse_of: :created_by
  has_many :canceled_trip_payment_requests,
    class_name: "TripPaymentRequest",
    foreign_key: :canceled_by_id,
    dependent: :nullify,
    inverse_of: :canceled_by
  has_many :completed_trip_readiness_tasks,
    class_name: "TripReadinessCompletion",
    foreign_key: :completed_by_id,
    dependent: :nullify,
    inverse_of: :completed_by
  has_many :sent_trip_details_emails,
    class_name: "TripDetailsEmail",
    foreign_key: :sent_by_id,
    dependent: :nullify,
    inverse_of: :sent_by
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :signed_up_trips, -> { distinct }, through: :campsite_signups, source: :trip
  has_many :signed_up_day_trips, -> { distinct }, through: :day_trip_signups, source: :trip
  has_many :signed_up_classes, -> { distinct }, through: :class_signups, source: :trip

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

  def self.generate_default_password
    SecureRandom.urlsafe_base64(24)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def public_name
    "#{first_name} #{last_name.to_s.first}."
  end

  def role_slugs
    if roles.loaded?
      roles.map(&:slug)
    else
      roles.pluck(:slug)
    end
  end

  def has_role?(slug)
    role_slugs.include?(slug.to_s)
  end

  def super_admin?
    has_role?("super_admin")
  end

  def finance_admin?
    has_role?("finance_admin")
  end

  def trip_admin?
    has_role?("trip_admin")
  end

  def admin_access?
    super_admin? || finance_admin? || trip_admin? || coordinated_trips.exists?
  end

  def current_waiver_for_year(year)
    waivers
      .signed
      .for_year(year)
      .with_attached_document
      .current_first
      .detect(&:current?)
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
      day_trip_signups.destroy_all
      class_signups.destroy_all
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
