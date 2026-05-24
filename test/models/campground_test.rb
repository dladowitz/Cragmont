require "test_helper"

class CampgroundTest < ActiveSupport::TestCase
  test "requires name and location" do
    campground = Campground.new

    assert_not campground.valid?
    assert_includes campground.errors[:name], "can't be blank"
    assert_includes campground.errors[:location], "can't be blank"
  end

  test "cannot be destroyed while campsites are assigned" do
    campground = campgrounds(:upper_pines)

    assert_no_difference "Campground.count" do
      campground.destroy
    end
    assert campground.errors[:base].any?
  end
end
