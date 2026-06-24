require "test_helper"

class TripDetailsEmailRendererTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:yosemite)
    campsites(:yosemite_b).update!(
      registered_by: users(:sam),
      registration_number: "YO-2026-A13"
    )
  end

  test "interpolates trip and campsite placeholders" do
    @trip.update!(group_campfire_campsite: campsites(:yosemite_a), group_fire_night: "saturday")
    renderer = TripDetailsEmailRenderer.new(
      trip: @trip,
      subject: "CCC {{trip_dates_short}}: {{campgrounds}}",
      body_markdown: "Trip: {{trip_name}}\n\n{{campsite_registration_info}}\n\n{{trip_page_url}}\n\n{{group_campfire_info}}\n\n{{group_campfire_site}} / {{group_fire_night}}"
    )

    assert_equal "CCC Jun 12-15, 2026: Upper Pines", renderer.rendered_subject
    assert_includes renderer.rendered_markdown, "Trip: Yosemite Valley Spring"
    assert_includes renderer.rendered_markdown, "**Upper Pines A12**"
    assert_includes renderer.rendered_markdown, "**Registration number:** YO-2026-A13"
    assert_includes renderer.rendered_markdown, "http://example.com/trips/#{@trip.id}"
    assert_includes renderer.rendered_markdown, "We'll have a group campfire at **Upper Pines site A12** on **Saturday evening**."
    assert_includes renderer.rendered_markdown, "Upper Pines site A12 / Saturday"
    assert_includes renderer.rendered_html, "<strong>Upper Pines A12</strong>"
  end

  test "interpolates trip photo album url" do
    @trip.update!(photo_album_url: "https://photos.google.com/share/yosemite-spring")
    renderer = TripDetailsEmailRenderer.new(
      trip: @trip,
      subject: "Details",
      body_markdown: "## Trip Photo Album\n\nThere is a trip photo album here: [{{photo_album_url}}]({{photo_album_url}})."
    )

    assert_includes renderer.rendered_markdown, "[https://photos.google.com/share/yosemite-spring](https://photos.google.com/share/yosemite-spring)"
    assert_includes renderer.rendered_html, 'href="https://photos.google.com/share/yosemite-spring"'
  end

  test "renders fallback group campfire info when no group campfire is selected" do
    renderer = TripDetailsEmailRenderer.new(
      trip: @trip,
      subject: "Details",
      body_markdown: "{{group_campfire_info}}"
    )

    assert_includes renderer.rendered_markdown, "No group campfire is planned yet."
  end

  test "tracks placeholder usage" do
    renderer = TripDetailsEmailRenderer.new(
      trip: @trip,
      subject: "Details",
      body_markdown: "{{campsite_registration_info}}"
    )

    assert renderer.uses_placeholder?("campsite_registration_info")
    assert_not renderer.uses_placeholder?("weather_url")
  end
end
