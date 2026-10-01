require "test_helper"

class Admin::FinancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "super admin can view the finances hub" do
    get admin_finances_url

    assert_response :success
    assert_select ".admin-nav a[href='#{admin_finances_path}']", text: "Finances"
    assert_select "h2", "Finances"
    assert_select ".finance-action-list a[href='#{admin_campsite_reimbursements_path}']", text: "Campsite Reimbursements"
    assert_select ".finance-action-list button[disabled]", text: "Trip Profitability — Coming soon"
    assert_select ".finance-action-list button[disabled]", text: "TBD — Coming soon"
  end

  test "finance and trip admins can view the finances hub" do
    %w[finance_admin trip_admin].each do |role_slug|
      admin = create_user!("#{role_slug}@example.com")
      assign_role(admin, role_slug)
      delete session_url
      log_in_as(admin)

      get admin_finances_url

      assert_response :success
      assert_select ".admin-nav a[href='#{admin_finances_path}']", text: "Finances"
    end
  end

  test "assigned campsite coordinator can view the finances hub" do
    coordinator = create_user!("coordinator@example.com")
    trips(:jtree).update!(campsite_coordinator: coordinator)
    delete session_url
    log_in_as(coordinator)

    get admin_finances_url

    assert_response :success
    assert_select ".admin-nav a[href='#{admin_finances_path}']", text: "Finances"
  end

  test "user without admin access cannot view the finances hub" do
    delete session_url
    log_in_as(users(:sam))

    get admin_finances_url

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end

  private

  def create_user!(email)
    User.create!(
      first_name: "Finley",
      last_name: "Crux",
      email: email,
      password: "password"
    )
  end
end
