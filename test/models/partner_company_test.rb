require "test_helper"

class PartnerCompanyTest < ActiveSupport::TestCase
  test "requires partner and primary contact details" do
    partner_company = PartnerCompany.new

    assert_not partner_company.valid?
    assert_includes partner_company.errors[:name], "can't be blank"
    assert_includes partner_company.errors[:website_url], "can't be blank"
    assert_includes partner_company.errors[:primary_contact_name], "can't be blank"
    assert_includes partner_company.errors[:primary_contact_phone], "can't be blank"
    assert_includes partner_company.errors[:primary_contact_email], "can't be blank"
  end
end
