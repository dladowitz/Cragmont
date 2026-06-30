require "test_helper"

class Admin::ContentPagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "super admin can edit camping trip what to expect page" do
    get edit_admin_content_page_url("what_to_expect")

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".admin-nav a[href='#{edit_admin_content_page_path("what_to_expect")}']", count: 0
    assert_select "h2", "Edit What to Expect on a Camping Trip"
    assert_select "label[for='content_page_title'] .required-marker", text: "*"
    assert_select "input[name='content_page[title]'][required]"
    assert_select "form[data-controller='markdown-preview'][data-markdown-preview-url-value='#{preview_admin_content_pages_path}']"
    assert_select "textarea[name='content_page[body]'][required][data-markdown-preview-target='source']", text: /## Camping trips/
    assert_select "a[href='https://www.markdownguide.org/basic-syntax/']", text: "View the full Markdown syntax guide."
    assert_select ".markdown-formatting-heading a[href='https://www.markdownguide.org/extended-syntax/']", text: "Full Markdown Reference"
    assert_select ".markdown-formatting-guide", text: /## Heading/
    assert_select ".markdown-formatting-guide", text: /\*\*bold text\*\*/
    assert_select ".markdown-formatting-guide", text: /\[Link text\]\(https:\/\/example\.com\)/
    assert_select ".content-page-preview[data-markdown-preview-target='preview'] h2", "Camping trips"
  end

  test "super admin can edit day trip what to expect page" do
    get edit_admin_content_page_url("day_trip_what_to_expect")

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select "h2", "Edit What to Expect on a Day Trip"
    assert_select "label[for='content_page_title'] .required-marker", text: "*"
    assert_select "input[name='content_page[title]'][required]"
    assert_select "form[data-controller='markdown-preview'][data-markdown-preview-url-value='#{preview_admin_content_pages_path}']"
    assert_select "textarea[name='content_page[body]'][required][data-markdown-preview-target='source']", text: /## Day trips/
    assert_select ".content-page-preview[data-markdown-preview-target='preview'] h2", "Day trips"
  end

  test "super admin can edit how to think about safety page" do
    get edit_admin_content_page_url("how_to_think_about_safety")

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select "h2", "Edit How to think about safety on trips"
    assert_select "label[for='content_page_title'] .required-marker", text: "*"
    assert_select "input[name='content_page[title]'][required]"
    assert_select "form[data-controller='markdown-preview'][data-markdown-preview-url-value='#{preview_admin_content_pages_path}']"
    assert_select "textarea[name='content_page[body]'][required][data-markdown-preview-target='source']", text: /## Before you trust a rope/
    assert_select ".content-page-preview[data-markdown-preview-target='preview'] h2", "Before you trust a rope"
  end

  test "super admin can preview markdown" do
    post preview_admin_content_pages_url, params: {
      body: "## Preview heading\n\nA [guide](https://example.com).\n\n<script>alert('x')</script>"
    }

    assert_response :success
    assert_includes response.body, "<h2>Preview heading</h2>"
    assert_includes response.body, 'href="https://example.com"'
    assert_includes response.body, 'target="_blank"'
    assert_not_includes response.body, "<script"
  end

  test "super admin can update camping trip what to expect page" do
    patch admin_content_page_url("what_to_expect"), params: {
      content_page: {
        title: "Updated Expectation Page",
        subtitle: "Updated subtitle.",
        body: "## Updated heading\n\nUpdated body."
      }
    }

    assert_redirected_to edit_admin_content_page_url("what_to_expect")
    page = ContentPage.current!("what_to_expect").reload
    assert_equal "Updated Expectation Page", page.title
    assert_equal "Updated subtitle.", page.subtitle
    assert_equal "## Updated heading\n\nUpdated body.", page.body
  end

  test "super admin can update day trip what to expect page" do
    patch admin_content_page_url("day_trip_what_to_expect"), params: {
      content_page: {
        title: "Updated Day Trip Expectation Page",
        subtitle: "Updated day trip subtitle.",
        body: "## Updated day trip heading\n\nUpdated day trip body."
      }
    }

    assert_redirected_to edit_admin_content_page_url("day_trip_what_to_expect")
    page = ContentPage.current!("day_trip_what_to_expect").reload
    assert_equal "Updated Day Trip Expectation Page", page.title
    assert_equal "Updated day trip subtitle.", page.subtitle
    assert_equal "## Updated day trip heading\n\nUpdated day trip body.", page.body
  end

  test "super admin can update how to think about safety page" do
    patch admin_content_page_url("how_to_think_about_safety"), params: {
      content_page: {
        title: "Updated Safety Page",
        subtitle: "Updated safety subtitle.",
        body: "## Updated safety\n\nCheck **everything**."
      }
    }

    assert_redirected_to edit_admin_content_page_url("how_to_think_about_safety")
    page = ContentPage.current!("how_to_think_about_safety").reload
    assert_equal "Updated Safety Page", page.title
    assert_equal "Updated safety subtitle.", page.subtitle
    assert_equal "## Updated safety\n\nCheck **everything**.", page.body
  end

  test "super admin sees validation errors" do
    patch admin_content_page_url("what_to_expect"), params: {
      content_page: {
        title: "",
        subtitle: "",
        body: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Title can't be blank/
    assert_select ".form-errors", text: /Body can't be blank/
  end

  test "non super admin cannot edit content pages" do
    delete session_url
    log_in_as(users(:sam))

    get edit_admin_content_page_url("what_to_expect")

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end
end
