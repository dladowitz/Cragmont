class SeedDayTripContentPages < ActiveRecord::Migration[8.1]
  WHAT_TO_EXPECT_PLACEHOLDER = <<~MARKDOWN.strip
    ## Content needs to be updated

    An admin should update this page using the Content markdown editor before publishing it.
  MARKDOWN

  WHAT_TO_EXPECT_BODY = <<~MARKDOWN.strip
    ## Camping trips

    Camping trips are multi-day outings built around shared campsites. You'll choose the nights you plan to attend, sign the annual waiver if needed, and pay any configured trip fees before your spot is fully dialed.

    ## Day trips

    Day trips are single-day cragging outings. You do not need to have a climbing partner lined up ahead of time, but you do need enough experience to safely participate outside.

    On day trips it is especially important to have the skills to assess anchors, ropes, belays, and advice from other climbers. Cragmont creates the social base camp; each participant is responsible for deciding what is safe to trust.

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

  def up
    execute <<~SQL
      INSERT INTO content_pages (slug, title, subtitle, body, created_at, updated_at)
      VALUES (
        'how_to_think_about_safety',
        'How to think about safety on trips',
        'A safety topo for making your own calls outside.',
        #{quote(SAFETY_BODY)},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT (slug) DO NOTHING
    SQL

    execute <<~SQL
      UPDATE content_pages
      SET body = #{quote(WHAT_TO_EXPECT_BODY)}, updated_at = CURRENT_TIMESTAMP
      WHERE slug = 'what_to_expect' AND body = #{quote(WHAT_TO_EXPECT_PLACEHOLDER)}
    SQL
  end

  def down
    execute "DELETE FROM content_pages WHERE slug = 'how_to_think_about_safety'"
  end
end
