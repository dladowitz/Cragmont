require "test_helper"

class CampsiteParkingSpotTest < ActiveSupport::TestCase
  test "requires known status" do
    assert_raises ArgumentError do
      campsite_parking_spots(:yosemite_a_1).status = "valet"
    end
  end

  test "assigned status requires a confirmed signup from the same trip" do
    spot = campsite_parking_spots(:yosemite_a_1)

    spot.status = "assigned"

    assert_not spot.valid?
    assert_includes spot.errors[:assigned_campsite_signup], "must be selected"

    waitlisted = create_waitlisted_signup!(
      trip: trips(:yosemite),
      user: User.create!(first_name: "Wendy", last_name: "Waitlist", email: "parking-wendy@example.com", password: "password")
    )
    spot.assigned_campsite_signup = waitlisted

    assert_not spot.valid?
    assert_includes spot.errors[:assigned_campsite_signup], "must be a confirmed participant"

    other_trip_signup = create_campsite_signup!(campsite: campsites(:jtree_a), user: users(:sam))
    spot.assigned_campsite_signup = other_trip_signup

    assert_not spot.valid?
    assert_includes spot.errors[:assigned_campsite_signup], "must belong to this trip"
  end

  test "can assign confirmed participant from another campsite on the same trip" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_b), user: users(:sam))
    spot = campsite_parking_spots(:yosemite_a_1)

    spot.update!(status: "assigned", assigned_campsite_signup: signup)

    assert spot.assigned?
    assert_equal signup, spot.assigned_campsite_signup
    assert_equal "Sam L.", spot.public_assignment_label
  end

  test "participant can only be assigned to one parking spot" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    first_spot = campsite_parking_spots(:yosemite_a_1)
    second_spot = campsite_parking_spots(:yosemite_a_2)
    first_spot.update!(status: "assigned", assigned_campsite_signup: signup)

    second_spot.status = "assigned"
    second_spot.assigned_campsite_signup = signup

    assert_not second_spot.valid?
    assert_includes second_spot.errors[:base], "The participant is already assigned to a parking spot"
    assert_equal [ "The participant is already assigned to a parking spot" ], second_spot.errors.full_messages
  end

  test "first come first serve clears assignment" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    spot = campsite_parking_spots(:yosemite_a_1)
    spot.update!(status: "assigned", assigned_campsite_signup: signup)

    spot.update!(status: "first_come_first_serve")

    assert spot.first_come_first_serve?
    assert_nil spot.assigned_campsite_signup
    assert_equal "First Come First Serve", spot.public_assignment_label
  end
end
