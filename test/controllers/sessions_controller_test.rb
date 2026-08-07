require "test_helper"
require "time"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "successful login persists session cookie for four months" do
    travel_to Time.zone.local(2026, 8, 7, 12, 0, 0) do
      post session_url, params: { email: "ALEX@EXAMPLE.COM", password: "password" }

      assert_redirected_to trips_url
      assert_equal "You are logged in.", flash[:notice]

      session_cookie = response.headers["Set-Cookie"].to_s.split("\n").find do |cookie|
        cookie.start_with?("_cragmont_session=")
      end

      assert session_cookie, "Expected the login response to set the session cookie"
      assert_match(/samesite=lax/i, session_cookie)

      expires_at = Time.httpdate(session_cookie.match(/expires=([^;]+)/i)[1])
      assert_operator expires_at, :>, 3.months.from_now
      assert_operator expires_at, :<, 5.months.from_now
    end
  end

  test "logout ends the authenticated session" do
    post session_url, params: { email: "alex@example.com", password: "password" }

    delete session_url

    assert_redirected_to root_url
    get profile_url

    assert_redirected_to new_session_url
  end
end
