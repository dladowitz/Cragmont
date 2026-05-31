require "test_helper"

class Admin::CampsitesControllerTest < ActionDispatch::IntegrationTest
  test "can render new campsite form" do
    get new_admin_trip_campsite_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".panel-header", text: /Yosemite Valley Spring/
    assert_select "input[name='campsite[arrival_date]'][min='2026-06-12'][max='2026-06-15']"
    assert_select "input[name='campsite[checkout_date]'][min='2026-06-12'][max='2026-06-15']"
  end

  test "can add campsite to trip" do
    assert_difference "Campsite.count", 1 do
      post admin_trip_campsites_url(trips(:yosemite)), params: {
        campsite: {
          campground_id: campgrounds(:upper_pines).id,
          site_number: "A14",
          arrival_date: "2026-06-13",
          checkout_date: "2026-06-15",
          participant_capacity: 8,
          car_capacity: 2,
          notes: "Extra site."
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
  end

  test "rejects campsite dates outside trip dates" do
    assert_no_difference "Campsite.count" do
      post admin_trip_campsites_url(trips(:yosemite)), params: {
        campsite: {
          campground_id: campgrounds(:upper_pines).id,
          site_number: "A14",
          arrival_date: "2026-06-11",
          checkout_date: "2026-06-16",
          participant_capacity: 8,
          car_capacity: 2,
          notes: "Extra site."
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Arrival date must be within the trip dates/
    assert_select ".form-errors", text: /Checkout date must be within the trip dates/
  end

  test "can render edit campsite form" do
    get edit_admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".panel-header", text: /Yosemite Valley Spring/
  end

  test "can update campsite" do
    patch admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a)), params: {
      campsite: {
        campground_id: campgrounds(:upper_pines).id,
        site_number: "A12B",
        arrival_date: campsites(:yosemite_a).arrival_date,
        checkout_date: campsites(:yosemite_a).checkout_date,
        participant_capacity: 7,
        car_capacity: 2,
        notes: campsites(:yosemite_a).notes
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "A12B", campsites(:yosemite_a).reload.site_number
    assert_equal 7, campsites(:yosemite_a).participant_capacity
  end

  test "can delete campsite" do
    assert_difference "Campsite.count", -1 do
      delete admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
  end

  test "cannot delete campsite with participants signed up" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_no_difference "Campsite.count" do
      delete admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Cannot delete campsite with participants signed up. Remove them or move to the waitlist first", flash[:alert]
  end
end
