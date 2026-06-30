require "test_helper"

class Admin::ContentControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "super admin can view content hub" do
    get admin_content_url

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".admin-nav a[href='#{admin_content_path}']", text: "Content"
    assert_select "h2", "Content for FAQs, Safety, Liability and Emails"
    assert_select ".content-action-list a[href='#{edit_admin_content_page_path("what_to_expect")}']", text: "Edit What to Expect on a Camping Trip"
    assert_select ".content-action-list a[href='#{edit_admin_content_page_path("day_trip_what_to_expect")}']", text: "Edit What to Expect on a Day Trip"
    assert_select ".content-action-list a[href='#{edit_admin_content_page_path("how_to_think_about_safety")}']", text: "Edit How to Think About Safety page"
    assert_select ".content-action-list a[href='#{admin_trip_details_email_templates_path}']", text: "Edit Trip Details Email Templates"
    assert_select ".content-action-list a[href='#{edit_admin_site_content_path("liability_warning")}']", text: "Edit Liability Warning"
    assert_select ".content-action-list a[href='#{edit_admin_site_content_path("day_trip_safety_reminder")}']", text: "Edit Day Trip Safety Reminder"
  end

  test "non super admin cannot view content hub" do
    delete session_url
    log_in_as(users(:sam))

    get admin_content_url

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end
end
