require "test_helper"

class EditorialUiTest < ActionDispatch::IntegrationTest
  test "homepage loads the shared design and keeps Admin by the brand" do
    log_in_as(users(:alex))

    get root_url

    assert_response :success
    assert_select "link[rel='stylesheet'][href*='editorial']"
    assert_select ".public-brand .public-admin-link", "Admin"
    assert_select ".home-hero h1 span", count: 3
  end
end
