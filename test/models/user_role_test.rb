require "test_helper"

class UserRoleTest < ActiveSupport::TestCase
  test "prevents duplicate role assignments for a user" do
    duplicate = UserRole.new(user: users(:alex), role: roles(:super_admin))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:role_id], "has already been taken"
  end
end
