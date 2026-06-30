require "test_helper"

class ContentPageTest < ActiveSupport::TestCase
  test "current creates default camping trip what to expect page" do
    page = ContentPage.current!("what_to_expect")

    assert page.persisted?
    assert_equal "what_to_expect", page.slug
    assert_equal "What to Expect on a Camping Trip", page.title
    assert_equal "A quick topo for sharing campsites with the club.", page.subtitle
    assert_includes page.body, "## Camping trips"
    assert_includes page.body, "shared campsites"
    assert_not_includes page.body, "## Day trips"
  end

  test "current creates default day trip what to expect page" do
    page = ContentPage.current!("day_trip_what_to_expect")

    assert page.persisted?
    assert_equal "day_trip_what_to_expect", page.slug
    assert_equal "What to Expect on a Day Trip", page.title
    assert_equal "A quick topo for single-day cragging with the club.", page.subtitle
    assert_includes page.body, "## Day trips"
    assert_includes page.body, "single-day cragging"
    assert_includes page.body, "/trips/how-to-think-about-safety"
  end

  test "current creates default safety page" do
    page = ContentPage.current!("how_to_think_about_safety")

    assert page.persisted?
    assert_equal "how_to_think_about_safety", page.slug
    assert_equal "How to think about safety on trips", page.title
    assert_includes page.body, "## Before you trust a rope"
    assert_includes page.body, "No one at Cragmont is a certified guide"
  end

  test "current rejects unknown slugs" do
    assert_raises(ActiveRecord::RecordNotFound) do
      ContentPage.current!("unknown_page")
    end
  end

  test "slug is unique" do
    ContentPage.current!("what_to_expect")
    duplicate = ContentPage.new(slug: "what_to_expect", title: "Duplicate", body: "Body")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end
end
