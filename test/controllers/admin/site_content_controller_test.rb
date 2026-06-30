require "test_helper"

class Admin::SiteContentControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "super admin can edit liability warning" do
    get edit_admin_site_content_url("liability_warning")

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select "h2", "Edit Liability Warning"
    assert_select "a[href='#{admin_content_path}']", text: "Back to Content"
    assert_select "label[for='site_setting_liability_warning'] .required-marker", text: "*"
    assert_select "textarea[name='site_setting[liability_warning]'][required]", text: /Cragmont is not a teaching organization/
    assert_select "form[data-controller='markdown-preview']", count: 0
  end

  test "super admin can update liability warning" do
    patch admin_site_content_url("liability_warning"), params: {
      site_setting: {
        liability_warning: "Custom admin liability warning."
      }
    }

    assert_redirected_to edit_admin_site_content_url("liability_warning")
    assert_equal "Custom admin liability warning.", SiteSetting.current.reload.liability_warning
  end

  test "super admin can edit day trip safety reminder" do
    get edit_admin_site_content_url("day_trip_safety_reminder")

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select "h2", "Edit Day Trip Safety Reminder"
    assert_select "a[href='#{admin_content_path}']", text: "Back to Content"
    assert_select "label[for='site_setting_day_trip_safety_reminder'] .required-marker", text: "*"
    assert_select "form[data-controller='markdown-preview'][data-markdown-preview-url-value='#{preview_admin_content_pages_path}']"
    assert_select "textarea[name='site_setting[day_trip_safety_reminder]'][required][data-markdown-preview-target='source']", text: /Climbing is dangerous/
    assert_select ".content-page-preview[data-markdown-preview-target='preview'] p", text: /Climbing is dangerous/
  end

  test "super admin can update day trip safety reminder" do
    patch admin_site_content_url("day_trip_safety_reminder"), params: {
      site_setting: {
        day_trip_safety_reminder: "## Day trip safety\n\nCustom **markdown** reminder."
      }
    }

    assert_redirected_to edit_admin_site_content_url("day_trip_safety_reminder")
    assert_equal "## Day trip safety\n\nCustom **markdown** reminder.", SiteSetting.current.reload.day_trip_safety_reminder
  end

  test "super admin sees validation errors" do
    patch admin_site_content_url("day_trip_safety_reminder"), params: {
      site_setting: {
        day_trip_safety_reminder: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Day trip safety reminder can't be blank/
  end

  test "non super admin cannot edit site content" do
    delete session_url
    log_in_as(users(:sam))

    get edit_admin_site_content_url("liability_warning")

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end
end
