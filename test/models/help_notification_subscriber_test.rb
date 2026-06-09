require "test_helper"

class HelpNotificationSubscriberTest < ActiveSupport::TestCase
  test "normalizes and validates email" do
    subscriber = HelpNotificationSubscriber.create!(email: " ADMIN@EXAMPLE.COM ")

    assert_equal "admin@example.com", subscriber.email

    duplicate = HelpNotificationSubscriber.new(email: "admin@example.com")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end
end
