class Resource < ApplicationRecord
  CATEGORIES = {
    "training" => "Training",
    "vendors" => "Vendors",
    "news" => "News",
    "upcoming-events" => "Upcoming Events"
  }.freeze
  KINDS = %w[link article].freeze
  TITLE_MAX = 150
  URL_MAX = 2000
  BODY_MAX = 50_000
  # Member-submitted links: no opener access, and no search-ranking endorsement.
  LINK_REL = "noopener nofollow ugc".freeze

  belongs_to :user

  normalizes :title, :url, with: ->(value) { value.strip }

  # Switching kinds on edit must not leave the other kind's content behind.
  before_validation { self.url = nil if article? }
  before_validation { self.body = nil if link? }

  validates :category, inclusion: { in: CATEGORIES.keys, message: "must be chosen from the list" }
  validates :kind, inclusion: { in: KINDS }
  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :url, presence: true, length: { maximum: URL_MAX }, if: :link?
  validates :body, presence: true, length: { maximum: BODY_MAX }, if: :article?
  validate :url_is_http, if: -> { link? && url.present? }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def link? = kind == "link"
  def article? = kind == "article"
  def category_name = CATEGORIES[category]

  private

  def url_is_http
    errors.add(:url, "must start with http:// or https://") unless ApplicationController.helpers.safe_external_url(url)
  end
end
