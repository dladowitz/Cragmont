class ContentPage < ApplicationRecord
  CAMPING_TRIP_WHAT_TO_EXPECT_BODY = <<~MARKDOWN.strip
    ## Camping trips

    Camping trips are multi-day outings built around shared campsites. You'll choose the nights you plan to attend, sign the annual waiver if needed, and pay any configured trip fees before your spot is fully dialed.

    You'll be sharing space with other participants, so expect to coordinate arrival times, parking, food, and camp chores with the campsite coordinator and the people in your site.

    Before the trip, make sure your participant details are complete, your waiver is signed, and any payment requests are handled so your spot is fully dialed.
  MARKDOWN

  DAY_TRIP_WHAT_TO_EXPECT_BODY = <<~MARKDOWN.strip
    ## Day trips

    Day trips are single-day cragging outings. You do not need to have a climbing partner lined up ahead of time, but you do need enough experience to safely participate outside.

    Expect to meet at the posted time and location, sort out any shared gear, and make a plan with the other participants at the crag.

    On day trips it is especially important to have the skills to assess anchors, ropes, belays, landing zones, and advice from other climbers. Cragmont creates the social base camp; each participant is responsible for deciding what is safe to trust.

    Read [How to think about safety on trips](/trips/how-to-think-about-safety) before heading to the crag.
  MARKDOWN

  SAFETY_BODY = <<~MARKDOWN.strip
    ## Before you trust a rope

    If you are new to climbing outside, here are some things you should be thinking about. If you are climbing on a top rope anchor someone else has put up, then you are trusting your life to that anchor. Did the person setting it up do it correctly? How do you know?

    Early on it can be hard to tell, especially since you likely cannot see the anchor until you have climbed to it.

    ## Check the source

    Another thing to ask yourself is how good the information is that you are reading now. Who wrote it? Was it peer reviewed? Is it just one person's musings?

    No one at Cragmont is a certified guide or trained by the AMGA. Cragmont is a social base camp, not a guiding or teaching organization.

    That said, if you are reading this and have additional thoughts or disagree with parts, send us feedback.
  MARKDOWN

  DEFAULT_PAGES = {
    "what_to_expect" => {
      title: "What to Expect on a Camping Trip",
      subtitle: "A quick topo for sharing campsites with the club.",
      body: CAMPING_TRIP_WHAT_TO_EXPECT_BODY
    },
    "day_trip_what_to_expect" => {
      title: "What to Expect on a Day Trip",
      subtitle: "A quick topo for single-day cragging with the club.",
      body: DAY_TRIP_WHAT_TO_EXPECT_BODY
    },
    "how_to_think_about_safety" => {
      title: "How to think about safety on trips",
      subtitle: "A safety topo for making your own calls outside.",
      body: SAFETY_BODY
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
