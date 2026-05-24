require "test_helper"

class Admin::TripsControllerTest < ActionDispatch::IntegrationTest
  test "can view trips index" do
    get admin_trips_url

    assert_response :success
    assert_select "h1", "Trips"
    assert_select "td", text: /Yosemite Valley Spring/
  end

  test "can view trip details with campsites" do
    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Yosemite Valley Spring"
    assert_select "h3", "Upper Pines"
    assert_select "td", text: "A12"
    assert_select ".campsite-notes-row", text: /Close to bathrooms/
  end

  test "can create trip" do
    assert_difference "Trip.count", 1 do
      post admin_trips_url, params: {
        trip: {
          name: "Smith Rock Summer",
          location: "Terrebonne, OR",
          start_date: "2026-08-01",
          end_date: "2026-08-04",
          description: "Tuff and sport climbing.",
          status: "draft"
        }
      }
    end

    assert_redirected_to admin_trip_url(Trip.order(:created_at).last)
  end

  test "can render new trip form" do
    get new_admin_trip_url

    assert_response :success
  end

  test "can update trip" do
    patch admin_trip_url(trips(:jtree)), params: {
      trip: {
        name: "Joshua Tree Winter Session",
        location: trips(:jtree).location,
        start_date: trips(:jtree).start_date,
        end_date: trips(:jtree).end_date,
        description: trips(:jtree).description,
        status: "published"
      }
    }

    assert_redirected_to admin_trip_url(trips(:jtree))
    assert_equal "Joshua Tree Winter Session", trips(:jtree).reload.name
    assert trips(:jtree).published?
  end

  test "can render edit trip form" do
    get edit_admin_trip_url(trips(:yosemite))

    assert_response :success
  end

  test "can delete trip" do
    trip = trips(:jtree)

    assert_difference "Trip.count", -1 do
      delete admin_trip_url(trip)
    end

    assert_redirected_to admin_trips_url
  end
end
