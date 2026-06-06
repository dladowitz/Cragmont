require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "can view users index" do
    User.create!(first_name: "Alex", last_name: "Boulder", email: "alex-boulder@example.com", password: "password")
    User.create!(first_name: "Aaron", last_name: "Anchor", email: "aaron-anchor@example.com", password: "password")
    User.create!(first_name: "Alex", last_name: "Arete", email: "alex-arete@example.com", password: "password")

    get admin_users_url

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select "h2", "User directory"
    assert_select "th", text: "Default Password"
    assert_select "a", text: "Alex Rivera"
    assert_select "tr", text: /Alex Rivera/ do
      assert_select ".member-icon[aria-label='Club member']", count: 1
      assert_select ".visually-hidden", text: "Club member"
      assert_select "td", text: "Yes"
    end
    assert_select "tr", text: /Sam Lee/ do
      assert_select ".member-icon", count: 0
      assert_select ".member-icon-placeholder", count: 1
      assert_select "td", text: "No"
    end
    names = css_select("tbody tr .user-name-cell a").map { |link| link.text.squish }
    assert_equal [
      "Aaron Anchor",
      "Alex Arete",
      "Alex Boulder",
      "Alex Rivera",
      "Sam Lee"
    ], names.first(5)
  end

  test "users index shows default password status" do
    guest = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "admin-default-password@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )

    get admin_users_url

    assert_response :success
    assert_select "tr", text: /Gina Guest/ do
      assert_select "td", text: "Yes"
    end
    assert guest.default_password?
  end

  test "can view user details" do
    get admin_user_url(users(:alex))

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".panel-header", text: /Alex Rivera/
    assert_select ".details-list dt", text: "Club member"
    assert_select ".details-list dd", text: "Yes"
    assert_select ".details-list dt", text: "Default Password"
    assert_select ".details-list dd", text: "No"
    assert_select "form[data-turbo-confirm='Are you sure you want to delete this user?']"
    assert_select "a", text: "Yosemite Valley Spring"
  end

  test "user details show default password status" do
    guest = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "admin-default-password-detail@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )

    get admin_user_url(guest)

    assert_response :success
    assert_select ".details-list dt", text: "Default Password"
    assert_select ".details-list dd", text: "Yes"
  end

  test "can create user" do
    assert_difference "User.count", 1 do
      post admin_users_url, params: {
        user: {
          first_name: "Morgan",
          last_name: "Chen",
          email: "morgan@example.com",
          phone: "555-0102",
          member: "1",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to admin_user_url(User.order(:created_at).last)
    assert User.order(:created_at).last.member?
  end

  test "can render new user form" do
    get new_admin_user_url

    assert_response :success
  end

  test "can update user" do
    patch admin_user_url(users(:sam)), params: {
      user: {
        first_name: "Samantha",
        last_name: users(:sam).last_name,
        email: users(:sam).email,
        phone: users(:sam).phone,
        member: users(:sam).member
      }
    }

    assert_redirected_to admin_user_url(users(:sam))
    assert_equal "Samantha", users(:sam).reload.first_name
  end

  test "admin create requires password" do
    assert_no_difference "User.count" do
      post admin_users_url, params: {
        user: {
          first_name: "No",
          last_name: "Password",
          email: "nopassword@example.com",
          member: "0"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Password can't be blank/
  end

  test "admin edit can leave password blank" do
    patch admin_user_url(users(:alex)), params: {
      user: {
        first_name: users(:alex).first_name,
        last_name: "Updated",
        email: users(:alex).email,
        phone: users(:alex).phone,
        member: users(:alex).member,
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to admin_user_url(users(:alex))
    assert_equal "Updated", users(:alex).reload.last_name
    assert users(:alex).authenticate("password")
  end

  test "can render edit user form" do
    get edit_admin_user_url(users(:alex))

    assert_response :success
    assert_select "fieldset.radio-field"
    assert_select "input[type=radio][name='user[member]'][value=true]"
    assert_select "input[type=radio][name='user[member]'][value=false]"
  end

  test "can delete unassigned user" do
    user = User.create!(first_name: "Unused", last_name: "Person", password: "password")

    assert_difference "User.count", -1 do
      delete admin_user_url(user)
    end

    assert_redirected_to admin_users_url
  end

  test "cannot delete assigned campsite coordinator" do
    assert_no_difference "User.count" do
      delete admin_user_url(users(:alex))
    end

    assert_redirected_to admin_user_url(users(:alex))
  end
end
