require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows trips overview with capacity totals" do
    CampsiteSignup.create!(campsite: campsites(:yosemite_a), user: users(:sam))
    Trip.create!(
      name: "Archived Trip",
      location: "Tahoe",
      start_date: Date.new(2026, 1, 10),
      end_date: Date.new(2026, 1, 12),
      status: "archived"
    )

    get admin_root_url

    assert_response :success
    assert_select "h1", "Admin dashboard"
    assert_select "th", text: "Participant Capacity"
    assert_select "th", text: "Signed Up"
    assert_select "td", text: /Yosemite Valley Spring/
    assert_select "td", text: "Alex Rivera"
    assert_select ".date-pair dt", text: "Arrival"
    assert_select ".date-pair dd", text: "June 12, 2026"
    assert_select ".date-pair dt", text: "Checkout"
    assert_select ".date-pair dd", text: "June 15, 2026"
    assert_select "td", text: "10"
    assert_select "td", text: "1"
    assert_select ".status.draft-status", text: "Draft"
    assert_select ".status.archived-status", text: "Archived"
    assert_select "th", text: "Cars", count: 0
  end
end
