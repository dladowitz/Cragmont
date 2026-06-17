require "test_helper"
require "fileutils"
require "tmpdir"

class ApplicationHelperTest < ActionView::TestCase
  test "visible environment name only appears for development and staging" do
    with_rails_env("development") do
      assert_equal "Development", visible_environment_name
      assert show_letter_opener_link?
    end

    with_rails_env("staging") do
      assert_equal "Staging", visible_environment_name
      assert_not show_letter_opener_link?
    end

    with_rails_env("production") do
      assert_nil visible_environment_name
      assert_not show_letter_opener_link?
    end
  end

  test "google analytics measurement id is production only" do
    with_env("GOOGLE_ANALYTICS_MEASUREMENT_ID" => "G-CRAGMONT1") do
      with_rails_env("production") do
        assert_equal "G-CRAGMONT1", google_analytics_measurement_id
      end

      with_rails_env("staging") do
        assert_nil google_analytics_measurement_id
      end

      with_rails_env("development") do
        assert_nil google_analytics_measurement_id
      end

      with_rails_env("test") do
        assert_nil google_analytics_measurement_id
      end
    end
  end

  test "google analytics measurement id is blank without production config" do
    with_rails_env("production") do
      with_env("GOOGLE_ANALYTICS_MEASUREMENT_ID" => nil) do
        assert_nil google_analytics_measurement_id
      end

      with_env("GOOGLE_ANALYTICS_MEASUREMENT_ID" => "") do
        assert_nil google_analytics_measurement_id
      end
    end
  end

  test "staging environment shows letter opener footer for super admins" do
    super_admin = users(:alex)

    with_current_user(super_admin) do
      with_rails_env("staging") do
        assert_equal "Staging", visible_environment_name
        assert show_letter_opener_link?
      end
    end
  end

  test "letter opener label includes readable message count" do
    Dir.mktmpdir do |dir|
      letters_location = Pathname.new(dir)
      FileUtils.mkdir_p(letters_location.join("first-message"))
      FileUtils.mkdir_p(letters_location.join("second-message"))
      FileUtils.touch(letters_location.join("not-a-message"))

      with_letter_opener_location(letters_location) do
        with_rails_env("development") do
          assert_equal 2, letter_opener_message_count
          assert_equal "Letter Opener (2)", letter_opener_label
        end
      end
    end
  end

  test "stripe dashboard payment url uses test path outside production" do
    with_env("STRIPE_ACCOUNT_ID" => "acct_test_123") do
      with_rails_env("development") do
        assert_equal(
          "https://dashboard.stripe.com/acct_test_123/test/payments/pi_test_123",
          stripe_dashboard_payment_url("pi_test_123")
        )
      end
    end
  end

  test "stripe dashboard payment url skips test path in production" do
    with_env("STRIPE_ACCOUNT_ID" => "acct_live_123") do
      with_rails_env("production") do
        assert_equal(
          "https://dashboard.stripe.com/acct_live_123/payments/pi_live_123",
          stripe_dashboard_payment_url("pi_live_123")
        )
      end
    end
  end

  test "stripe dashboard payment url is blank without required ids" do
    with_env("STRIPE_ACCOUNT_ID" => nil) do
      assert_nil stripe_dashboard_payment_url("pi_test_123")
    end

    with_env("STRIPE_ACCOUNT_ID" => "acct_test_123") do
      assert_nil stripe_dashboard_payment_url(nil)
    end
  end

  private

  def with_rails_env(env_name)
    original_env = Rails.env
    Rails.define_singleton_method(:env) { ActiveSupport::StringInquirer.new(env_name) }

    yield
  ensure
    Rails.define_singleton_method(:env) { original_env }
  end

  def with_letter_opener_location(location)
    singleton_class.define_method(:letter_opener_letters_location) { location }

    yield
  ensure
    singleton_class.remove_method(:letter_opener_letters_location)
  end

  def with_current_user(user)
    singleton_class.define_method(:current_user) { user }

    yield
  ensure
    singleton_class.remove_method(:current_user)
  end

  def with_env(values)
    originals = values.keys.index_with { |key| ENV[key] }
    values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    originals.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
