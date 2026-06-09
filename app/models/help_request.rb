class HelpRequest < ApplicationRecord
  ACCESS_TOKEN_PURPOSE = :help_request_access
  MAX_UPLOAD_SIZE = 3.megabytes
  MAX_UPLOAD_SIZE_LABEL = "3 MB".freeze
  STATUSES = %w[open replied resolved].freeze

  REASONS = {
    "site_issue" => "Report site issue",
    "club_question" => "Question about club",
    "trip_help" => "Need help with trip",
    "other" => "Other"
  }.freeze

  belongs_to :user, optional: true
  has_many :replies, class_name: "HelpRequestReply", dependent: :destroy
  has_many_attached :images

  attr_accessor :first_name, :last_name

  normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }
  normalizes :name, with: ->(name) { name.to_s.strip.presence }
  normalizes :subject, with: ->(subject) { subject.to_s.strip.presence }

  validates :reason, inclusion: { in: REASONS.keys }
  validates :name, :email, :subject, :message, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validate :images_are_supported_types
  validate :images_are_within_size_limit

  before_validation :compose_name_from_parts
  before_validation :link_user_by_email, if: -> { user_id.blank? && email.present? }

  scope :recent_first, -> { order(created_at: :desc) }

  def reason_label
    REASONS.fetch(reason, reason.to_s.humanize)
  end

  def mark_replied!
    update!(status: "replied", last_replied_at: Time.current)
  end

  def mark_open!
    update!(status: "open")
  end

  def mark_resolved!
    update!(status: "resolved")
  end

  private

  def compose_name_from_parts
    return if name.present?

    self.name = [ first_name, last_name ].map { |part| part.to_s.strip }.reject(&:blank?).join(" ").presence
  end

  def link_user_by_email
    self.user = User.find_by(email: email)
  end

  def images_are_supported_types
    images.each do |image|
      next if image.content_type.in?(%w[image/png image/jpeg image/gif image/webp])

      errors.add(:images, "must be PNG, JPG, GIF, or WebP screenshots")
    end
  end

  def images_are_within_size_limit
    images.each do |image|
      next if image.byte_size <= MAX_UPLOAD_SIZE

      errors.add(:images, "must be #{MAX_UPLOAD_SIZE_LABEL} or smaller")
    end
  end
end
