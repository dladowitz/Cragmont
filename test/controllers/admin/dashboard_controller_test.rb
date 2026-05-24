require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows trips overview with capacity totals" do
    get admin_root_url

    assert_response :success
    assert_select "h1", "Admin dashboard"
    assert_select "td", text: /Yosemite Valley Spring/
    assert_select "td", text: "Alex Rivera"
    assert_select "td", text: "10"
    assert_select "td", text: "3"
  end
end
