require "test_helper"

class EditorialUiTest < ActionDispatch::IntegrationTest
  test "homepage loads the shared design and keeps Admin by the brand" do
    log_in_as(users(:alex))

    get root_url

    assert_response :success
    assert_select "link[rel='stylesheet'][href*='editorial']"
    assert_select ".public-brand a.public-admin-link[href='#{admin_root_path}']", "Admin"
    assert_select ".home-hero h1 span", count: 3
  end

  test "admin headers clearly label the dashboard and offer one public view link" do
    assign_role(users(:sam), :trip_admin)
    log_in_as(users(:sam))

    [ admin_trips_url, admin_trip_url(trips(:yosemite)), admin_trip_reports_url ].each do |url|
      get url
      assert_response :success
      assert_select ".admin-brand a.admin-public-link[href='#{root_path}']", "Public View"
      assert_select ".admin-mode-label", "Admin Dashboard"
      assert_select ".admin-context", count: 0
      assert_select "a.admin-public-link", count: 1
    end

    get admin_root_url
    assert_redirected_to admin_trips_url
    follow_redirect!
    assert_response :success
  end
end
