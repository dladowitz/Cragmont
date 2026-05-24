require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "can view users index" do
    get admin_users_url

    assert_response :success
    assert_select "h1", "Users"
    assert_select "td", text: "Alex Rivera"
  end

  test "can view user details" do
    get admin_user_url(users(:alex))

    assert_response :success
    assert_select "h1", "Alex Rivera"
    assert_select ".details-list dt", text: "Club member"
    assert_select ".details-list dd", text: "Yes"
    assert_select "form[data-turbo-confirm='Are you sure you want to delete this user?']"
    assert_select "a", text: "Yosemite Valley Spring"
  end

  test "can create user" do
    assert_difference "User.count", 1 do
      post admin_users_url, params: {
        user: {
          first_name: "Morgan",
          last_name: "Chen",
          email: "morgan@example.com",
          phone: "555-0102",
          member: "1"
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

  test "can render edit user form" do
    get edit_admin_user_url(users(:alex))

    assert_response :success
    assert_select "fieldset.radio-field"
    assert_select "input[type=radio][name='user[member]'][value=true]"
    assert_select "input[type=radio][name='user[member]'][value=false]"
  end

  test "can delete unassigned user" do
    user = User.create!(first_name: "Unused", last_name: "Person")

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
