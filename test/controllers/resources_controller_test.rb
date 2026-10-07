require "test_helper"

class ResourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @link = Resource.create!(user: users(:sam), category: "training", kind: "link",
      title: "Fingerboard plan", url: "https://example.com/fingers", created_at: 2.days.ago)
    @article = Resource.create!(user: users(:sam), category: "training", kind: "article",
      title: "Footwork drills", body: "## Warm up\n\nQuiet feet.", created_at: 1.day.ago)
    @riley = User.create!(first_name: "Riley", last_name: "Stone", email: "riley@example.com", password: "password")
  end

  def link_params(**overrides)
    { resource: { kind: "link", category: "vendors", title: "Local gear shop", url: "https://gear.example.com" }.merge(overrides) }
  end

  test "navigation has a Resources dropdown between Trips and Club" do
    get resource_category_path("training")
    assert_select "nav.public-nav > details", count: 3
    assert_select "nav.public-nav > details:nth-child(2) summary", "Resources"
    assert_select "nav.public-nav > details:nth-child(2) a" do |links|
      assert_equal [ "Training", "Vendors", "News", "Upcoming Events" ], links.map(&:text)
      assert_equal %w[training vendors news upcoming-events].map { |slug| "/resources/#{slug}" }, links.map { |link| link["href"] }
    end
  end

  test "signed-out visitors read each category newest first with safe external links" do
    Resource::CATEGORIES.each do |slug, name|
      get resource_category_path(slug)
      assert_response :success
      assert_select "body.club-page"
      assert_select "h1", name
      assert_select "main a[href=?]", new_resource_path(category: slug), text: "Submit a resource"
    end

    get resource_category_path("training")
    assert_select ".resource-entry h2", count: 2
    assert_select ".resource-entry h2" do |titles|
      assert_equal [ "Footwork drills", "Fingerboard plan (opens in a new tab)" ], titles.map { |title| title.text.squish }
    end
    assert_select "a[href='https://example.com/fingers'][target='_blank'][rel='noopener nofollow ugc']"
    assert_select "a[href='#{resource_article_path('training', @article)}']", "Footwork drills"
    assert_select ".resource-entry", text: /Shared by Sam L\./
    assert_select ".resource-entry", text: /example\.com/
    assert_select ".resource-actions", count: 0

    get resource_category_path("news")
    assert_select ".resource-entry", count: 0
    assert_select "main", text: /Nothing here yet/
  end

  test "signed-out visitors read articles" do
    get resource_article_path("training", @article)
    assert_response :success
    assert_select "body.club-page"
    assert_select "h1", "Footwork drills"
    assert_select ".club-copy h2", "Warm up"
    assert_select ".resource-actions", count: 0
  end

  test "unknown categories, mismatched categories, and link ids are not found" do
    get "/resources/gear"
    assert_response :not_found
    get resource_article_path("news", @article)
    assert_response :not_found
    get resource_article_path("training", @link)
    assert_response :not_found
  end

  test "signed-out visitors are sent through login and back to the form" do
    get new_resource_path(category: "news")
    assert_redirected_to new_session_path(return_to: "/resources/new?category=news")
    get edit_resource_path(@link)
    assert_redirected_to new_session_path(return_to: edit_resource_path(@link))

    assert_no_difference "Resource.count" do
      post resources_path, params: link_params
    end
    assert_redirected_to new_session_path(return_to: new_resource_path)

    patch resource_path(@link), params: link_params(title: "Hijacked")
    assert_redirected_to new_session_path(return_to: new_resource_path)
    delete resource_path(@link)
    assert_equal "Fingerboard plan", @link.reload.title

    post session_url, params: { email: users(:sam).email, password: "password", return_to: "/resources/new?category=news" }
    assert_redirected_to "/resources/new?category=news"
    follow_redirect!
    assert_select "select[name='resource[category]'] option[selected][value='news']"
    assert_select "input[type='radio'][value='link'][checked]"
  end

  test "form marks required fields and hides the unused kind" do
    log_in_as users(:sam)
    get new_resource_path(category: "training")
    assert_response :success
    assert_select "label[for='resource_category'] .required-marker", "*"
    assert_select "label[for='resource_title'] .required-marker", "*"
    assert_select "label[for='resource_url'] .required-marker", "*"
    assert_select "label[for='resource_body'] .required-marker", "*"
    assert_select "select#resource_category[required]"
    assert_select "input#resource_title[required][maxlength='#{Resource::TITLE_MAX}']"
    assert_select "fieldset:not([hidden]):not([disabled]) input#resource_url[type='url'][required]"
    assert_select "fieldset[hidden][disabled] textarea#resource_body[required]"
    assert_select "[data-action='resource-form#format']", count: 4
  end

  test "an unknown preselected category is ignored" do
    log_in_as users(:sam)
    get new_resource_path(category: "gear")
    assert_response :success
    assert_select "select[name='resource[category]'] option[selected]", count: 0
  end

  test "signed-in member publishes a link immediately" do
    log_in_as users(:sam)
    assert_difference "Resource.count", 1 do
      post resources_path, params: link_params(user_id: users(:alex).id)
    end
    resource = Resource.order(:id).last
    assert_equal users(:sam), resource.user
    assert_redirected_to resource_category_path("vendors")
    follow_redirect!
    assert_select ".flash.notice .flash-text", "On belay! Your resource is up."
    assert_select "a[href='https://gear.example.com'][rel='noopener nofollow ugc']", /Local gear shop/
  end

  test "signed-in member publishes an article immediately" do
    log_in_as users(:sam)
    post resources_path, params: { resource: { kind: "article", category: "upcoming-events", title: "Spring social", body: "Bring **snacks**.", url: "https://ignored.example.com" } }
    resource = Resource.order(:id).last
    assert resource.article?
    assert_nil resource.url
    assert_redirected_to resource_category_path("upcoming-events")
    follow_redirect!
    assert_select "a[href='#{resource_article_path('upcoming-events', resource)}']", "Spring social"
    get resource_article_path("upcoming-events", resource)
    assert_select ".club-copy strong", "snacks"
  end

  test "invalid input re-renders with errors and keeps entered data" do
    log_in_as users(:sam)
    assert_no_difference "Resource.count" do
      post resources_path, params: link_params(title: "My beta", url: "javascript:alert(1)")
    end
    assert_response :unprocessable_entity
    assert_select ".flash.alert .flash-text", /Whipper!/
    assert_select ".form-errors li", "Link must start with http:// or https://"
    assert_select "input#resource_title[value='My beta']"
    assert_select "input#resource_url[value='javascript:alert(1)']"
    assert_select "select#resource_category option[selected][value='vendors']"

    post resources_path, params: { resource: { kind: "article", category: "news", title: "", body: "Draft words" } }
    assert_response :unprocessable_entity
    assert_select ".form-errors li", "Title can't be blank"
    assert_select "textarea#resource_body", "Draft words"
    assert_select "input[type='radio'][value='article'][checked]"
    assert_select "fieldset:not([hidden]) textarea#resource_body"
    assert_select "fieldset[hidden][disabled] input#resource_url"
  end

  test "author edits and deletes their own resource" do
    log_in_as users(:sam)
    get resource_category_path("training")
    assert_select ".resource-actions", count: 2
    get edit_resource_path(@link)
    assert_response :success
    assert_select "input#resource_title[value='Fingerboard plan']"

    patch resource_path(@link), params: link_params(category: "training", title: "Fingerboard plan v2")
    assert_redirected_to resource_category_path("training")
    assert_equal "Fingerboard plan v2", @link.reload.title

    patch resource_path(@link), params: link_params(url: "ftp://example.com")
    assert_response :unprocessable_entity
    assert_equal "https://gear.example.com", @link.reload.url

    assert_difference "Resource.count", -1 do
      delete resource_path(@article)
    end
    assert_redirected_to resource_category_path("training")
  end

  test "another member cannot edit or delete someone else's resource" do
    log_in_as @riley
    get resource_category_path("training")
    assert_select ".resource-actions", count: 0
    get resource_article_path("training", @article)
    assert_select ".resource-actions", count: 0

    get edit_resource_path(@link)
    assert_redirected_to root_path
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
    patch resource_path(@link), params: link_params(title: "Hijacked")
    assert_redirected_to root_path
    assert_no_difference "Resource.count" do
      delete resource_path(@link)
    end
    assert_equal "Fingerboard plan", @link.reload.title
  end

  test "global admins can edit and delete any resource" do
    log_in_as users(:alex)
    get resource_article_path("training", @article)
    assert_select ".resource-actions", count: 1
    assert_difference "Resource.count", -1 do
      delete resource_path(@article)
    end

    assign_role(@riley, :trip_admin)
    log_in_as @riley
    patch resource_path(@link), params: link_params(category: "training", title: "Moderated")
    assert_equal "Moderated", @link.reload.title
    assert_equal users(:sam), @link.user
  end

  test "finance admins and trip coordinators are not resource moderators" do
    assign_role(@riley, :finance_admin)
    trips(:yosemite).update!(campsite_coordinator: @riley)
    log_in_as @riley
    assert_no_difference "Resource.count" do
      delete resource_path(@link)
    end
  end

  test "article markdown cannot run scripts" do
    @article.update!(body: <<~MARKDOWN)
      <script>alert('xss')</script>
      <img src=x onerror="alert('xss')">

      [click me](javascript:alert('xss')) and [real](https://example.com/real)
    MARKDOWN

    get resource_article_path("training", @article)
    assert_response :success
    body = css_select(".club-copy").to_html
    assert_no_match(/<script/i, body)
    assert_no_match(/onerror/i, body)
    assert_no_match(/javascript:/i, body)
    assert_select ".club-copy a[href='https://example.com/real'][target='_blank'][rel='noopener nofollow ugc']", "real"
    assert_select ".club-copy a[href='']", "click me"
    assert_select ".club-copy img", count: 0
  end

  test "titles are escaped" do
    @link.update!(title: "<script>alert('xss')</script>")
    get resource_category_path("training")
    assert_no_match(/<script>alert/, css_select("main").to_html)
  end
end
