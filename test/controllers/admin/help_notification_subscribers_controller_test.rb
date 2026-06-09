require "test_helper"

class Admin::HelpNotificationSubscribersControllerTest < ActionDispatch::IntegrationTest
  test "super admin can manage notification emails" do
    log_in_as(users(:alex))

    get admin_help_notification_subscribers_url
    assert_response :success
    assert_select "h2", "Help notification emails"

    assert_difference "HelpNotificationSubscriber.count", 1 do
      post admin_help_notification_subscribers_url, params: {
        help_notification_subscriber: {
          email: "helper@example.com"
        }
      }
    end

    subscriber = HelpNotificationSubscriber.last
    assert_redirected_to admin_help_notification_subscribers_url

    assert_difference "HelpNotificationSubscriber.count", -1 do
      delete admin_help_notification_subscriber_url(subscriber)
    end
  end

  test "non super admin cannot manage notification emails" do
    assign_role(users(:sam), :trip_admin)
    log_in_as(users(:sam))

    get admin_help_notification_subscribers_url

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end
end
