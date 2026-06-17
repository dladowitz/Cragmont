require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "current returns a persisted settings row with defaults" do
    setting = SiteSetting.current

    assert setting.persisted?
    assert_equal 13, setting.uncounted_minor_age_limit
    assert_equal 0, setting.first_two_nights_fee_cents
    assert_equal 0, setting.extra_night_fee_cents
    assert_equal 0, setting.minor_fee_cents
    assert_equal 0, setting.minor_extra_night_fee_cents
    assert_equal SiteSetting::DEFAULT_LIABILITY_WARNING, setting.liability_warning
  end

  test "stores dollar fee inputs as cents" do
    setting = SiteSetting.current

    setting.update!(
      first_two_nights_fee: "42.50",
      extra_night_fee: "11.25",
      minor_fee: "8",
      minor_extra_night_fee: "4.75"
    )

    assert_equal 4250, setting.first_two_nights_fee_cents
    assert_equal 1125, setting.extra_night_fee_cents
    assert_equal 800, setting.minor_fee_cents
    assert_equal 475, setting.minor_extra_night_fee_cents
  end
end
