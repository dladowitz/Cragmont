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
end
