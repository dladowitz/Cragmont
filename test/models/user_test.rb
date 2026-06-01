require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires first and last name" do
    user = User.new

    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "allows blank email" do
    user = User.new(first_name: "Blank", last_name: "Email", password: "password")

    assert user.valid?
  end

  test "requires password on create" do
    user = User.new(first_name: "No", last_name: "Password")

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "authenticates with email and password" do
    user = users(:alex)

    assert user.authenticate("password")
    assert_not user.authenticate("wrong-password")
  end

  test "default password flag is explicit and clears when password changes" do
    user = User.create!(
      first_name: "Guest",
      last_name: "Climber",
      email: "guest-climber@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )

    assert user.default_password?

    user.update!(password: "new-password", password_confirmation: "new-password")

    assert_not user.default_password?
  end

  test "generates password reset token and finds user with valid token" do
    user = users(:alex)
    token = user.generate_password_reset_token!

    user.reload
    assert user.password_reset_token_digest.present?
    assert user.password_reset_sent_at.present?
    assert_not_equal token, user.password_reset_token_digest
    assert_equal user, User.find_by_password_reset_token(token)
    assert_nil User.find_by_password_reset_token("wrong-token")
  end

  test "password reset token expires and clears after password change" do
    user = users(:alex)
    token = user.generate_password_reset_token!

    user.update_column(:password_reset_sent_at, 24.hours.ago)
    assert user.valid_password_reset_token?(token)

    user.update_column(:password_reset_sent_at, 49.hours.ago)
    assert_not user.valid_password_reset_token?(token)

    user.update!(password: "new-password", password_confirmation: "new-password")

    assert_nil user.password_reset_token_digest
    assert_nil user.password_reset_sent_at
  end

  test "rejects duplicate nonblank email case insensitively" do
    user = User.new(first_name: "Duplicate", last_name: "Email", email: "ALEX@EXAMPLE.COM", password: "password")

    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "cannot be destroyed while assigned as coordinator" do
    user = users(:alex)

    assert_no_difference "User.count" do
      user.destroy
    end
    assert user.errors[:base].any?
  end

  test "full name combines first and last name" do
    assert_equal "Alex Rivera", users(:alex).full_name
  end

  test "public name abbreviates last name" do
    assert_equal "Alex R.", users(:alex).public_name
  end
end
