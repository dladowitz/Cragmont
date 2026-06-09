require "test_helper"

class AdminResourcePolicyTest < ActiveSupport::TestCase
  setup do
    @super_admin = users(:alex)
    @trip_admin = users(:sam)
    assign_role(@trip_admin, :trip_admin)
    @finance_admin = User.create!(first_name: "Finley", last_name: "Finance", email: "finley-finance@example.com", password: "password")
    assign_role(@finance_admin, :finance_admin)
  end

  test "user and site setting policies are super admin only" do
    assert UserPolicy.new(@super_admin, users(:sam)).update?
    assert SiteSettingPolicy.new(@super_admin, SiteSetting.current).update?

    assert_not UserPolicy.new(@trip_admin, users(:sam)).update?
    assert_not SiteSettingPolicy.new(@trip_admin, SiteSetting.current).update?
    assert_not UserPolicy.new(@finance_admin, users(:sam)).show?
  end

  test "campground policy allows super and trip admins only" do
    campground = campgrounds(:upper_pines)

    assert CampgroundPolicy.new(@super_admin, campground).update?
    assert CampgroundPolicy.new(@trip_admin, campground).update?
    assert_not CampgroundPolicy.new(@finance_admin, campground).index?
  end
end
