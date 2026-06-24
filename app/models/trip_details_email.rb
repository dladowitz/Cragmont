class TripDetailsEmail < ApplicationRecord
  STATUSES = %w[draft sent].freeze

  belongs_to :trip
  belongs_to :trip_details_email_template
  belongs_to :sent_by, class_name: "User", optional: true
  has_many :trip_details_email_recipients, dependent: :destroy

  enum :status, STATUSES.index_with(&:itself), default: "draft"

  validates :status, :subject, :body_markdown, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :trip_id, uniqueness: true
  validates :rendered_html_snapshot, :rendered_text_snapshot, :template_name_snapshot, :template_area_key_snapshot, :sent_at, :sent_by, presence: true, if: :sent?

  validate :sent_email_is_locked, on: :update

  def editable?
    draft?
  end

  def delivered_recipients_count
    trip_details_email_recipients.delivered.count
  end

  def failed_recipients_count
    trip_details_email_recipients.failed.count
  end

  private

  def sent_email_is_locked
    return unless status_in_database == "sent"
    return unless changed?

    errors.add(:base, "Sent trip details emails cannot be changed")
  end
end
