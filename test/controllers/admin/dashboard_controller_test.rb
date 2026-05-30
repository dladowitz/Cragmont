require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects admin root to trips" do
    get admin_root_url

    assert_redirected_to admin_trips_url
  end
end
