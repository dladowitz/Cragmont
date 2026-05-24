require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires first and last name" do
    user = User.new

    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "allows blank email" do
    user = User.new(first_name: "Blank", last_name: "Email")

    assert user.valid?
  end

  test "rejects duplicate nonblank email case insensitively" do
    user = User.new(first_name: "Duplicate", last_name: "Email", email: "ALEX@EXAMPLE.COM")

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
end
