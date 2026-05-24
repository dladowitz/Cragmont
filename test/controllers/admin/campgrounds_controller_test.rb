require "test_helper"

class Admin::CampgroundsControllerTest < ActionDispatch::IntegrationTest
  test "can view campgrounds index" do
    get admin_campgrounds_url

    assert_response :success
    assert_select "h1", "Campgrounds"
    assert_select "td", text: "Upper Pines"
  end

  test "can view campground details" do
    get admin_campground_url(campgrounds(:upper_pines))

    assert_response :success
    assert_select "h1", "Upper Pines"
    assert_select "td", text: "A12"
  end

  test "can create campground" do
    assert_difference "Campground.count", 1 do
      post admin_campgrounds_url, params: {
        campground: {
          name: "Camp 4",
          location: "Yosemite National Park",
          website: "https://example.com/camp-4",
          notes: "Classic climber campground."
        }
      }
    end

    assert_redirected_to admin_campground_url(Campground.order(:created_at).last)
  end

  test "can render new campground form" do
    get new_admin_campground_url

    assert_response :success
  end

  test "can update campground" do
    patch admin_campground_url(campgrounds(:hidden_valley)), params: {
      campground: {
        name: "Hidden Valley Campground",
        location: "Joshua Tree National Park",
        website: campgrounds(:hidden_valley).website,
        notes: campgrounds(:hidden_valley).notes
      }
    }

    assert_redirected_to admin_campground_url(campgrounds(:hidden_valley))
    assert_equal "Hidden Valley Campground", campgrounds(:hidden_valley).reload.name
  end

  test "can render edit campground form" do
    get edit_admin_campground_url(campgrounds(:upper_pines))

    assert_response :success
  end

  test "can delete unused campground" do
    campground = Campground.create!(name: "Unused", location: "Somewhere")

    assert_difference "Campground.count", -1 do
      delete admin_campground_url(campground)
    end

    assert_redirected_to admin_campgrounds_url
  end
end
