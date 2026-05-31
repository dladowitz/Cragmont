require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "public header links signed in user name to profile" do
    log_in_as(users(:alex))

    get trips_url

    assert_response :success
    assert_select ".public-nav a[href='#{profile_path}']", text: "Alex Rivera"
  end

  test "logged in user can view profile" do
    log_in_as(users(:alex))

    get profile_url

    assert_response :success
    assert_select "h1", "Alex Rivera"
    assert_select ".details-list dt", text: "Email"
    assert_select ".details-list dd", text: "alex@example.com"
    assert_select ".details-list dt", text: "Phone"
    assert_select ".details-list dd", text: "555-0100"
    assert_select ".details-list dt", text: "Club member"
    assert_select ".details-list dd", text: "Yes"
    assert_select "a[href='#{edit_profile_path}']", text: "Edit profile"
    assert_select "button", text: "Delete account"
    assert_select "dialog.confirmation-modal", text: /Are you sure you want to delete your account\?/
    assert_select "dialog.confirmation-modal", text: /This will delete all history and current trips/
    assert_select "label[for='confirmation_text']", text: "Type Delete Me to Confirm"
    assert_select "input[name='confirmation_text']"
    assert_select "input[type='submit'][disabled]", value: "Delete account"
    assert_select "a", text: "Yosemite Valley Spring"
  end

  test "profile edit excludes club member control" do
    log_in_as(users(:alex))

    get edit_profile_url

    assert_response :success
    assert_select "input[name='user[first_name]'][value='Alex']"
    assert_select "input[name='user[last_name]'][value='Rivera']"
    assert_select "input[name='user[email]'][value='alex@example.com']"
    assert_select "input[name='user[phone]'][value='555-0100']"
    assert_select ".password-visibility-field[data-controller='password-visibility']", count: 2
    assert_select "button.password-visibility-toggle[aria-label='Show password']", count: 2
    assert_select "input[type='password'][data-password-visibility-target='input']", count: 2
    assert_select "input[type='radio'][name='user[member]']", count: 0
    assert_select "fieldset.radio-field", count: 0
  end

  test "logged in user can update profile without changing member status" do
    log_in_as(users(:sam))

    patch profile_url, params: {
      user: {
        first_name: "Samuel",
        last_name: users(:sam).last_name,
        email: "samuel@example.com",
        phone: "555-0199",
        member: "1",
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to profile_url
    users(:sam).reload
    assert_equal "Samuel", users(:sam).first_name
    assert_equal "samuel@example.com", users(:sam).email
    assert_equal "555-0199", users(:sam).phone
    assert_not users(:sam).member?
  end

  test "delete account requires confirmation text" do
    log_in_as(users(:sam))

    assert_no_difference "User.count" do
      delete profile_url, params: { confirmation_text: "Delete" }
    end

    assert_redirected_to profile_url
    assert_equal "Type Delete Me to confirm account deletion.", flash[:alert]
  end

  test "user can delete account and trip history" do
    user = User.create!(first_name: "Temporary", last_name: "Member", email: "temporary@example.com", password: "password")
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: user)
    campsites(:yosemite_b).update!(registered_by: user)
    trips(:jtree).update!(campsite_coordinator: user)
    log_in_as(user)

    assert_difference "User.count", -1 do
      assert_difference "CampsiteSignup.count", -1 do
        delete profile_url, params: { confirmation_text: "Delete Me" }
      end
    end

    assert_redirected_to root_url
    assert_equal "Your account was deleted.", flash[:notice]
    assert_nil CampsiteSignup.find_by(id: signup.id)
    assert_nil campsites(:yosemite_b).reload.registered_by
    assert_nil trips(:jtree).reload.campsite_coordinator
  end

  test "logged out user is redirected from profile" do
    get profile_url

    assert_redirected_to new_session_url
  end

  private

  def log_in_as(user)
    post session_url, params: { email: user.email, password: "password" }
  end
end
