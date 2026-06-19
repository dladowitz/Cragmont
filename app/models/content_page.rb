class ContentPage < ApplicationRecord
  WHAT_TO_EXPECT_BODY = <<~MARKDOWN.strip
    ## Content needs to be updated

    An admin should update this page using the Content markdown editor before publishing it.
  MARKDOWN

  DEFAULT_PAGES = {
    "what_to_expect" => {
      title: "What to expect on a Cragmont trip",
      subtitle: "A quick topo for your first outing with the club.",
      body: WHAT_TO_EXPECT_BODY
    }
  }.freeze

  validates :slug, presence: true, uniqueness: true
  validates :title, :body, presence: true

  def self.current!(slug)
    default_attributes = DEFAULT_PAGES.fetch(slug) { raise ActiveRecord::RecordNotFound, "Unknown content page: #{slug}" }

    find_or_create_by!(slug: slug) do |page|
      page.title = default_attributes.fetch(:title)
      page.subtitle = default_attributes.fetch(:subtitle)
      page.body = default_attributes.fetch(:body)
    end
  end
end
