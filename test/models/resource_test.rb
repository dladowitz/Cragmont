require "test_helper"

class ResourceTest < ActiveSupport::TestCase
  def link(**attributes)
    Resource.new({ user: users(:sam), category: "training", kind: "link", title: "Hangboard basics", url: "https://example.com/hang" }.merge(attributes))
  end

  def article(**attributes)
    Resource.new({ user: users(:sam), category: "news", kind: "article", title: "Club news", body: "We sent it." }.merge(attributes))
  end

  test "valid link and article" do
    assert link.valid?
    assert article.valid?
  end

  test "category must be one of the four slugs" do
    Resource::CATEGORIES.each_key { |slug| assert link(category: slug).valid?, slug }
    [ nil, "", "Training", "gear", "upcoming_events" ].each do |category|
      resource = link(category: category)
      assert_not resource.valid?, category.inspect
      assert_includes resource.errors[:category], "must be chosen from the list"
    end
  end

  test "kind must be link or article" do
    [ nil, "", "video" ].each { |kind| assert_not link(kind: kind).valid?, kind.inspect }
  end

  test "requires an author and a title within limits" do
    assert_not link(user: nil).valid?
    assert_not link(title: "   ").valid?
    assert link(title: "a" * Resource::TITLE_MAX).valid?
    assert_not link(title: "a" * (Resource::TITLE_MAX + 1)).valid?
  end

  test "links only accept http and https URLs with a host" do
    [ "http://example.com", "https://example.com/a?b=c", " https://example.com " ].each do |url|
      assert link(url: url).valid?, url
    end
    [ nil, "", "javascript:alert(1)", "JaVaScRiPt:alert(1)", "ftp://example.com/file", "data:text/html,hi",
      "https://", "//example.com", "example.com", "http://exa mple.com" ].each do |url|
      resource = link(url: url)
      assert_not resource.valid?, url.inspect
      assert resource.errors[:url].any?
    end
    assert_not link(url: "https://example.com/#{'a' * Resource::URL_MAX}").valid?
  end

  test "error messages name the Link field" do
    resource = link(url: "javascript:alert(1)")
    resource.valid?
    assert_includes resource.errors.full_messages, "Link must start with http:// or https://"
  end

  test "articles require a body within limits" do
    assert_not article(body: "").valid?
    assert_includes article(body: nil).tap(&:valid?).errors.full_messages, "Article can't be blank"
    assert article(body: "a" * Resource::BODY_MAX).valid?
    assert_not article(body: "a" * (Resource::BODY_MAX + 1)).valid?
  end

  test "drops the other kind's content" do
    resource = link(body: "stray")
    resource.save!
    assert_nil resource.body
    resource.update!(kind: "article", body: "Now an article")
    assert_nil resource.reload.url
  end

  test "strips title and url whitespace" do
    resource = link(title: "  Spaced  ", url: "  https://example.com  ")
    assert_equal "Spaced", resource.title
    assert_equal "https://example.com", resource.url
  end

  test "newest first" do
    old = link(title: "Old", created_at: 2.days.ago).tap(&:save!)
    newest = link(title: "Newest", created_at: 1.hour.ago).tap(&:save!)
    middle = article(title: "Middle", created_at: 1.day.ago).tap(&:save!)
    assert_equal [ newest, middle, old ], Resource.newest_first.to_a
  end

  test "deleting an account deletes its resources" do
    user = User.create!(first_name: "Temp", last_name: "Climber", email: "temp@example.com", password: "password")
    link(user: user).save!
    assert_difference "Resource.count", -1 do
      user.destroy_account_with_history!
    end
  end
end
