require "test_helper"

class Admin::CampsiteParkingSpotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "admin can mark parking spot first come first serve" do
    spot = campsite_parking_spots(:yosemite_a_1)

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), spot), params: {
      campsite_parking_spot: {
        assignment: "first_come_first_serve"
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite), anchor: "admin-campsite-#{campsites(:yosemite_a).id}")
    assert_equal "On belay! Parking was updated.", flash[:notice]
    assert spot.reload.first_come_first_serve?
    assert_nil spot.assigned_campsite_signup
  end

  test "admin can update parking spot with json response" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    spot = campsite_parking_spots(:yosemite_a_1)
    campsite_parking_spots(:yosemite_a_2).update!(status: "first_come_first_serve")

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), spot), params: {
      campsite_parking_spot: {
        assignment: "signup_#{signup.id}"
      }
    }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "On belay! Parking was updated.", payload.fetch("message")
    assert_equal "signup_#{signup.id}", payload.fetch("assignment")
    assert_equal 1, payload.fetch("assigned_count")
    assert_equal 1, payload.fetch("first_come_first_serve_count")
  end

  test "admin can update parking spot with browser fetch headers" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    spot = campsite_parking_spots(:yosemite_a_1)

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), spot, format: :json), params: {
      campsite_parking_spot: {
        assignment: "signup_#{signup.id}"
      }
    }, headers: {
      "Accept" => "application/json",
      "X-Requested-With" => "XMLHttpRequest"
    }

    assert_response :success
    assert_equal "application/json", response.media_type
    payload = JSON.parse(response.body)
    assert_equal "signup_#{signup.id}", payload.fetch("assignment")
    assert_equal signup, spot.reload.assigned_campsite_signup
  end

  test "admin can update parking spot with rails form method override to json" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    spot = campsite_parking_spots(:yosemite_a_1)

    post admin_trip_campsite_parking_spot_url(trips(:yosemite), spot, format: :json), params: {
      _method: "patch",
      campsite_parking_spot: {
        assignment: "signup_#{signup.id}"
      }
    }, headers: {
      "Accept" => "application/json",
      "X-Requested-With" => "XMLHttpRequest"
    }

    assert_response :success
    assert_equal "application/json", response.media_type
    payload = JSON.parse(response.body)
    assert_equal "signup_#{signup.id}", payload.fetch("assignment")
    assert_equal signup, spot.reload.assigned_campsite_signup
  end

  test "admin can assign parking spot to confirmed participant from any campsite on trip" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_b), user: users(:sam))
    spot = campsite_parking_spots(:yosemite_a_1)

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), spot), params: {
      campsite_parking_spot: {
        assignment: "signup_#{signup.id}"
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite), anchor: "admin-campsite-#{campsites(:yosemite_a).id}")
    assert_equal "On belay! Parking was updated.", flash[:notice]
    assert spot.reload.assigned?
    assert_equal signup, spot.assigned_campsite_signup
  end

  test "admin cannot assign parking spot to waitlisted participant" do
    signup = create_waitlisted_signup!(
      trip: trips(:yosemite),
      user: User.create!(first_name: "Wendy", last_name: "Waitlist", email: "admin-parking-wendy@example.com", password: "password")
    )
    spot = campsite_parking_spots(:yosemite_a_1)

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), spot), params: {
      campsite_parking_spot: {
        assignment: "signup_#{signup.id}"
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite), anchor: "admin-campsite-#{campsites(:yosemite_a).id}")
    assert_equal "Assigned campsite signup must be a confirmed participant", flash[:alert]
    assert spot.reload.unassigned?
  end

  test "admin cannot choose invalid parking assignment" do
    spot = campsite_parking_spots(:yosemite_a_1)

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), spot), params: {
      campsite_parking_spot: {
        assignment: "valet"
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite), anchor: "admin-campsite-#{campsites(:yosemite_a).id}")
    assert_equal "Choose a valid parking assignment.", flash[:alert]
    assert spot.reload.unassigned?
  end

  test "invalid json parking assignment returns error without redirect" do
    spot = campsite_parking_spots(:yosemite_a_1)

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), spot), params: {
      campsite_parking_spot: {
        assignment: "signup_0"
      }
    }, as: :json

    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    assert_equal "Assigned campsite signup must be selected", payload.fetch("message")
    assert spot.reload.unassigned?
  end

  test "duplicate participant assignment uses friendly json message" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    campsite_parking_spots(:yosemite_a_1).update!(status: "assigned", assigned_campsite_signup: signup)
    second_spot = campsite_parking_spots(:yosemite_a_2)

    patch admin_trip_campsite_parking_spot_url(trips(:yosemite), second_spot), params: {
      campsite_parking_spot: {
        assignment: "signup_#{signup.id}"
      }
    }, as: :json

    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    assert_equal "The participant is already assigned to a parking spot", payload.fetch("message")
    assert second_spot.reload.unassigned?
  end
end
