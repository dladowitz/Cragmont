require "test_helper"

class ContentPageTest < ActiveSupport::TestCase
  test "current creates default what to expect page" do
    page = ContentPage.current!("what_to_expect")

    assert page.persisted?
    assert_equal "what_to_expect", page.slug
    assert_equal "What to expect on a Cragmont trip", page.title
    assert_equal "A quick topo for your first outing with the club.", page.subtitle
    assert_includes page.body, "## Content needs to be updated"
    assert_includes page.body, "Content markdown editor"
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
