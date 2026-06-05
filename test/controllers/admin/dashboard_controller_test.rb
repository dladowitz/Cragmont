require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "redirects admin root to trips" do
    get admin_root_url

    assert_redirected_to admin_trips_url
  end

  test "logged out admin pages redirect to login" do
    delete session_url

    get admin_trips_url

    assert_redirected_to new_session_url
    assert_equal "Please log in to access admin pages.", flash[:alert]
  end

  test "logged out admin writes redirect to login" do
    delete session_url

    post admin_trips_url, params: {
      trip: {
        name: "Unauthorized Peak",
        location: "Nowhere",
        start_date: "2026-08-01",
        end_date: "2026-08-02",
        status: "draft"
      }
    }

    assert_redirected_to new_session_url
    assert_not Trip.exists?(name: "Unauthorized Peak")
  end
end
