require "test_helper"

class Admin::PartnerCompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "can view partner companies index" do
    get admin_partner_companies_url

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".admin-nav a[href='#{admin_partner_companies_path}']", text: "Partners"
    assert_select "h2", "Partner companies"
    assert_select "td", text: "Vertical World Guides"
    assert_select "a[href='#{new_admin_partner_company_path}']", text: "New partner"
  end

  test "can view partner company details" do
    get admin_partner_company_url(partner_companies(:vertical_world))

    assert_response :success
    assert_select "h2", "Vertical World Guides"
    assert_select "dt", text: "Primary Contact"
    assert_select "dd", text: /Vera Guide, 555-0190, vera@example.com/
    assert_select "a[href='#{edit_admin_partner_company_path(partner_companies(:vertical_world))}']", text: "Edit Company"
  end

  test "can create partner company" do
    assert_difference "PartnerCompany.count", 1 do
      post admin_partner_companies_url, params: {
        partner_company: {
          name: "Golden Gate Guides",
          website_url: "https://example.com/golden-gate",
          primary_contact_name: "Gina Guide",
          primary_contact_phone: "555-0192",
          primary_contact_email: "gina@example.com",
          secondary_contact_name: "Parker Partner",
          secondary_contact_phone: "555-0193",
          secondary_contact_email: "parker@example.com",
          description: "AMGA-certified instruction."
        }
      }
    end

    assert_redirected_to admin_partner_company_url(PartnerCompany.order(:created_at).last)
  end

  test "trip admin can manage partner companies" do
    trip_admin = users(:sam)
    assign_role(trip_admin, :trip_admin)
    delete session_url
    log_in_as(trip_admin)

    get admin_partner_companies_url

    assert_response :success
    assert_select ".admin-nav a[href='#{admin_partner_companies_path}']", text: "Partners"
  end
end
