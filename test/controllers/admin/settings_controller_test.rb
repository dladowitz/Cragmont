require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "can view settings" do
    get admin_settings_url

    assert_response :success
    assert_select "h1", "Settings"
    assert_select "label", text: "Age limit of uncounted minors"
    assert_select "label", text: "Campsite weekend fee"
    assert_select "label", text: "Campsite extra night fee"
    assert_select "label", text: "Minor fee"
    assert_select ".currency-field", count: 3
    assert_select ".currency-field span", text: "$", count: 3
  end

  test "can update settings" do
    patch admin_settings_url, params: {
      site_setting: {
        uncounted_minor_age_limit: "12",
        campsite_weekend_fee: "35.50",
        campsite_extra_night_fee: "10",
        minor_fee: "5.25"
      }
    }

    assert_redirected_to admin_settings_url
    setting = SiteSetting.current.reload
    assert_equal 12, setting.uncounted_minor_age_limit
    assert_equal 3550, setting.campsite_weekend_fee_cents
    assert_equal 1000, setting.campsite_extra_night_fee_cents
    assert_equal 525, setting.minor_fee_cents
  end

  test "renders validation errors" do
    patch admin_settings_url, params: {
      site_setting: {
        uncounted_minor_age_limit: "18",
        campsite_weekend_fee: "0",
        campsite_extra_night_fee: "0",
        minor_fee: "0"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Uncounted minor age limit/
  end
end
