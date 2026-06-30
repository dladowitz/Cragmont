class SplitWhatToExpectContentPages < ActiveRecord::Migration[8.1]
  OLD_WHAT_TO_EXPECT_BODY = <<~MARKDOWN.strip
    ## Camping trips

    Camping trips are multi-day outings built around shared campsites. You'll choose the nights you plan to attend, sign the annual waiver if needed, and pay any configured trip fees before your spot is fully dialed.

    ## Day trips

    Day trips are single-day cragging outings. You do not need to have a climbing partner lined up ahead of time, but you do need enough experience to safely participate outside.

    On day trips it is especially important to have the skills to assess anchors, ropes, belays, and advice from other climbers. Cragmont creates the social base camp; each participant is responsible for deciding what is safe to trust.

    Read [How to think about safety on trips](/trips/how-to-think-about-safety) before heading to the crag.
  MARKDOWN

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

  def up
    execute <<~SQL
      UPDATE content_pages
      SET
        title = 'What to Expect on a Camping Trip',
        subtitle = 'A quick topo for sharing campsites with the club.',
        body = #{quote(CAMPING_TRIP_WHAT_TO_EXPECT_BODY)},
        updated_at = CURRENT_TIMESTAMP
      WHERE slug = 'what_to_expect'
        AND body = #{quote(OLD_WHAT_TO_EXPECT_BODY)}
    SQL

    execute <<~SQL
      UPDATE content_pages
      SET
        title = 'What to Expect on a Camping Trip',
        subtitle = 'A quick topo for sharing campsites with the club.',
        updated_at = CURRENT_TIMESTAMP
      WHERE slug = 'what_to_expect'
    SQL

    execute <<~SQL
      INSERT INTO content_pages (slug, title, subtitle, body, created_at, updated_at)
      VALUES (
        'day_trip_what_to_expect',
        'What to Expect on a Day Trip',
        'A quick topo for single-day cragging with the club.',
        #{quote(DAY_TRIP_WHAT_TO_EXPECT_BODY)},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT (slug) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM content_pages WHERE slug = 'day_trip_what_to_expect'"
  end
end
