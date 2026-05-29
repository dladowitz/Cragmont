require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "current returns a persisted settings row with defaults" do
    setting = SiteSetting.current

    assert setting.persisted?
    assert_equal 13, setting.uncounted_minor_age_limit
    assert_equal 0, setting.campsite_weekend_fee_cents
    assert_equal 0, setting.campsite_extra_night_fee_cents
    assert_equal 0, setting.minor_fee_cents
  end

  test "stores dollar fee inputs as cents" do
    setting = SiteSetting.current

    setting.update!(
      campsite_weekend_fee: "42.50",
      campsite_extra_night_fee: "11.25",
      minor_fee: "8"
    )

    assert_equal 4250, setting.campsite_weekend_fee_cents
    assert_equal 1125, setting.campsite_extra_night_fee_cents
    assert_equal 800, setting.minor_fee_cents
  end
end
