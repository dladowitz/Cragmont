require "test_helper"

class Admin::TripDetailsEmailTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
    TripDetailsEmailTemplate.ensure_defaults!
    @template = TripDetailsEmailTemplate.find_by!(area_key: "yosemite", name: "Yosemite")
  end

  test "super admin can list trip details email templates" do
    get admin_trip_details_email_templates_url

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select "h2", "Trip Details Email Templates"
    assert_select "td", text: "Yosemite"
    assert_select "td", text: "yosemite"
    assert_select ".status.success-status", text: "Active"
    assert_select "a[href='#{edit_admin_trip_details_email_template_path(@template)}']", text: "Edit"
    assert_select "a[href='#{admin_content_path}']", text: "Back to Content"
  end

  test "super admin can edit trip details email template" do
    get edit_admin_trip_details_email_template_url(@template)

    assert_response :success
    assert_select "h2", "Edit Yosemite Template"
    assert_select "label[for='trip_details_email_template_name'] .required-marker", text: "*"
    assert_select "input[name='trip_details_email_template[name]'][required][value='Yosemite']"
    assert_select "input[name='area_key_display'][disabled][value='yosemite']"
    assert_select "input[name='trip_details_email_template[subject_template]'][required][value='#{@template.subject_template}']"
    assert_select "input[name='trip_details_email_template[active]'][type='checkbox'][checked]"
    assert_select "form[data-controller='markdown-preview'][data-markdown-preview-url-value='#{preview_admin_trip_details_email_templates_path}']"
    assert_select "textarea[name='trip_details_email_template[body_markdown]'][required][data-markdown-preview-target='source']", text: /Campsite Assignments/
    assert_select "textarea[name='trip_details_email_template[body_markdown]']", text: /## Campfire.*\{\{group_campfire_info\}\}/m
    assert_select "textarea[name='trip_details_email_template[body_markdown]']", text: /## Trip Photo Album.*\{\{photo_album_url\}\}/m
    assert_select ".trip-details-email-markdown[data-markdown-preview-target='preview'] h2", "Campsite Assignments & Check-In (READ THIS)"
    assert_select ".trip-details-email-markdown[data-markdown-preview-target='preview'] h2", "Trip Photo Album"
  end

  test "super admin can update trip details email template" do
    patch admin_trip_details_email_template_url(@template), params: {
      trip_details_email_template: {
        name: "Yosemite Updated",
        subject_template: "Updated {{trip_dates}}",
        body_markdown: "## Updated template\n\nBring snacks.",
        active: "0"
      }
    }

    assert_redirected_to edit_admin_trip_details_email_template_url(@template)
    @template.reload
    assert_equal "Yosemite Updated", @template.name
    assert_equal "Updated {{trip_dates}}", @template.subject_template
    assert_equal "## Updated template\n\nBring snacks.", @template.body_markdown
    assert_not @template.active?
  end

  test "super admin can preview template markdown" do
    post preview_admin_trip_details_email_templates_url, params: {
      body: "## Template heading\n\nA [guide](https://example.com).\n\n<script>alert('x')</script>"
    }

    assert_response :success
    assert_includes response.body, "<h2>Template heading</h2>"
    assert_includes response.body, 'href="https://example.com"'
    assert_includes response.body, 'target="_blank"'
    assert_not_includes response.body, "<script"
  end

  test "non super admin cannot edit trip details email templates" do
    delete session_url
    log_in_as(users(:sam))

    get admin_trip_details_email_templates_url

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end
end
