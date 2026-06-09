require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "renders the custom not found page" do
    get "/404"

    assert_response :not_found
    assert_select "body.not-found-page"
    assert_select "h1", "Off route!"
    assert_select "p", "That page doesn't exist"
    assert_select ".background-image-caption", "Indian Creek, UT"
  end
end
