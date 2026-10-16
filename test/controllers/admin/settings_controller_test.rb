require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "can view settings" do
    SiteSetting.current.update!(first_two_nights_fee: "30", extra_night_fee: "10", minor_fee: "15", minor_extra_night_fee: "5")

    get admin_settings_url

    assert_response :success
    assert_select "h1.visually-hidden"
    assert_select "h2", "Camping Trip Settings"
    assert_select "label[for='site_setting_camping_member_priority_days'] .required-marker", text: "*"
    assert_select "input[name='site_setting[camping_member_priority_days]'][value='15'][required]"
    assert_select ".admin-nav a[href='#{admin_content_path}']", text: "Content"
    assert_select "h2", text: "Content", count: 0
    assert_select "label", text: /Age limit of uncounted minors/
    assert_select "label[for='site_setting_uncounted_minor_age_limit'] .required-marker", text: "*"
    assert_select "label[for='site_setting_first_two_nights_fee']", text: "One or Two Nights"
    assert_select "label[for='site_setting_extra_night_fee']", text: "Additional Nights Fee"
    assert_select "label[for='site_setting_minor_fee']", text: "Minor One or Two Nights"
    assert_select "label[for='site_setting_minor_extra_night_fee']", text: "Minor Additional Nights Fee"
    assert_select "textarea[name='site_setting[liability_warning]']", count: 0
    assert_select "textarea[name='site_setting[day_trip_safety_reminder]']", count: 0
    assert_select ".currency-field", count: 4
    assert_select ".currency-field span", text: "$", count: 4
    assert_select "input[name='site_setting[first_two_nights_fee]'][value='30.00']"
    assert_select "input[name='site_setting[extra_night_fee]'][value='10.00']"
    assert_select "input[name='site_setting[minor_fee]'][value='15.00']"
    assert_select "input[name='site_setting[minor_extra_night_fee]'][value='5.00']"
  end

  test "can update settings" do
    patch admin_settings_url, params: {
      site_setting: {
        camping_member_priority_days: "21",
        uncounted_minor_age_limit: "12",
        first_two_nights_fee: "35.50",
        extra_night_fee: "10",
        minor_fee: "5.25",
        minor_extra_night_fee: "3"
      }
    }

    assert_redirected_to admin_settings_url
    setting = SiteSetting.current.reload
    assert_equal 21, setting.camping_member_priority_days
    assert_equal 12, setting.uncounted_minor_age_limit
    assert_equal 3550, setting.first_two_nights_fee_cents
    assert_equal 1000, setting.extra_night_fee_cents
    assert_equal 525, setting.minor_fee_cents
    assert_equal 300, setting.minor_extra_night_fee_cents
  end

  test "renders validation errors" do
    patch admin_settings_url, params: {
      site_setting: {
        uncounted_minor_age_limit: "18",
        first_two_nights_fee: "0",
        extra_night_fee: "0",
        minor_fee: "0",
        minor_extra_night_fee: "0"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Uncounted minor age limit/
  end

  test "rejects invalid member priority duration and does not save it" do
    patch admin_settings_url, params: { site_setting: { camping_member_priority_days: "-1" } }
    assert_response :unprocessable_entity
    assert_equal 15, SiteSetting.current.camping_member_priority_days
    assert_select ".form-errors", text: /Camping member priority days/
  end

  test "non admins cannot change the duration" do
    log_in_as(users(:sam))
    patch admin_settings_url, params: { site_setting: { camping_member_priority_days: "0" } }
    assert_equal 15, SiteSetting.current.camping_member_priority_days
    assert_response :redirect
  end
end
