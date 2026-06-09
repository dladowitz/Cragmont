require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "validates known role slugs" do
    role = Role.new(name: "Invalid", slug: "route_setter")

    assert_not role.valid?
    assert_includes role.errors[:slug], "is not included in the list"
  end

  test "seeds default roles idempotently" do
    assert_no_difference "Role.count" do
      Role.seed_defaults!
    end

    assert_equal "Super Admin", roles(:super_admin).reload.name
    assert_equal "Finance Admin", roles(:finance_admin).reload.name
    assert_equal "Trip Admin", roles(:trip_admin).reload.name
  end
end
