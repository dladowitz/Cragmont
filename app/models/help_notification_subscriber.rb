class HelpNotificationSubscriber < ApplicationRecord
  normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }

  validates :email, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }

  scope :alphabetical, -> { order(:email) }
end
