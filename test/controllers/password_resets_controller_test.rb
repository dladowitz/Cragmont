require "test_helper"
require "cgi"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "login page links to password reset" do
    get new_session_url

    assert_response :success
    assert_select "a[href='#{new_password_reset_path}']", "Forgot password?"
    assert_select ".background-image-caption", "Super Crack, Indian Creek"
  end

  test "reset request form renders required email field" do
    get new_password_reset_url

    assert_response :success
    assert_select "body.password-reset-new-page"
    assert_select "h1", "Reset password"
    assert_select "label[for='email'] .required-marker", text: "*"
    assert_select "input[type='email'][name='email'][required]"
    assert_select "input[type='submit'][value='Send reset link']"
    assert_select ".background-image-caption", "Castleton Tower, Castle Valley, UT"
  end

  test "known email receives password reset link" do
    user = users(:alex)

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post password_resets_url, params: { email: " ALEX@EXAMPLE.COM " }
    end

    assert_redirected_to new_session_url
    assert_equal "We found your email in our system. A password reset link is being sent", flash[:notice]

    user.reload
    assert user.password_reset_token_digest.present?
    assert user.password_reset_sent_at.present?

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "alex@example.com" ], mail.to
    assert_equal "Reset your Cragmont password", mail.subject
    assert_match "This link expires in 48 hours.", mail.text_part.body.decoded
    assert_no_match "alex%40example.com", mail.text_part.body.decoded

    token = reset_token_from(mail)
    assert_not_equal token, user.password_reset_token_digest
    assert_equal user, User.find_by_password_reset_token(token)
  end

  test "unknown email does not send a reset email" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      post password_resets_url, params: { email: "nobody@example.com" }
    end

    assert_response :unprocessable_entity
    assert_select ".flash.alert", "That email isn't tied into Cragmont yet. Check the address or create an account."
    assert_select "input[type='email'][name='email'][value='nobody@example.com']"
  end

  test "valid password reset link renders password form" do
    token = users(:alex).generate_password_reset_token!

    get edit_password_reset_url(token)

    assert_response :success
    assert_select "body.password-reset-edit-page"
    assert_select "h1", "Choose a new password"
    assert_select ".password-visibility-field[data-controller='password-visibility']", count: 2
    assert_select "input[type='password'][name='user[password]'][required]"
    assert_select "input[type='password'][name='user[password_confirmation]'][required]"
    assert_select "input[type='submit'][value='Reset password']"
    assert_select ".background-image-caption", "Yosemite Valley, Arrowhead Arete"
  end

  test "user can reset password with valid token" do
    user = users(:alex)
    token = user.generate_password_reset_token!

    patch password_reset_url(token), params: {
      user: {
        password: "new-secure-password",
        password_confirmation: "new-secure-password"
      }
    }

    assert_redirected_to new_session_url
    assert_equal "On belay! Your password has been reset.", flash[:notice]

    user.reload
    assert_nil user.password_reset_token_digest
    assert_nil user.password_reset_sent_at
    assert user.authenticate("new-secure-password")
    assert_not user.authenticate("password")
  end

  test "expired password reset token redirects to request form" do
    user = users(:alex)
    token = user.generate_password_reset_token!
    user.update_column(:password_reset_sent_at, 49.hours.ago)

    patch password_reset_url(token), params: {
      user: {
        password: "new-secure-password",
        password_confirmation: "new-secure-password"
      }
    }

    assert_redirected_to new_password_reset_url
    assert_equal "That reset link took a whipper. Please request a new one.", flash[:alert]
    assert user.reload.authenticate("password")
  end

  test "invalid password confirmation keeps reset form open" do
    user = users(:alex)
    token = user.generate_password_reset_token!

    patch password_reset_url(token), params: {
      user: {
        password: "new-secure-password",
        password_confirmation: "different-password"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Password confirmation doesn't match Password/
    assert user.reload.authenticate("password")
  end

  private

  def reset_token_from(mail)
    body = mail.text_part.body.decoded
    match = body.match(%r{/password_resets/([^/\s]+)/edit})

    assert match, "Expected reset URL in email body"

    CGI.unescape(match[1])
  end
end
