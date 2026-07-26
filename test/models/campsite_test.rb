require "test_helper"

class CampsiteTest < ActiveSupport::TestCase
  test "requires core fields" do
    campsite = Campsite.new

    assert_not campsite.valid?
    assert_includes campsite.errors[:trip], "must exist"
    assert_includes campsite.errors[:campground], "must exist"
    assert_includes campsite.errors[:site_number], "can't be blank"
    assert_includes campsite.errors[:arrival_date], "can't be blank"
    assert_includes campsite.errors[:checkout_date], "can't be blank"
    assert_includes campsite.errors[:participant_capacity], "can't be blank"
    assert_includes campsite.errors[:car_capacity], "can't be blank"
  end

  test "participant capacity must be between zero and fifty" do
    campsite = campsites(:yosemite_a)

    campsite.participant_capacity = -1
    assert_not campsite.valid?
    assert_includes campsite.errors[:participant_capacity], "must be greater than or equal to 0"

    campsite.participant_capacity = 51
    assert_not campsite.valid?
    assert_includes campsite.errors[:participant_capacity], "must be less than or equal to 50"
  end

  test "car capacity must be non negative" do
    campsite = campsites(:yosemite_a)
    campsite.car_capacity = -1

    assert_not campsite.valid?
    assert_includes campsite.errors[:car_capacity], "must be greater than or equal to 0"
  end

  test "registration fee converts dollars to cents" do
    campsite = campsites(:yosemite_a)

    campsite.registration_fee = "$123.45"

    assert_equal 12345, campsite.registration_fee_cents
    assert_equal BigDecimal("123.45"), campsite.registration_fee
  end

  test "registration fee cannot be negative" do
    campsite = campsites(:yosemite_a)
    campsite.registration_fee = "-1.00"

    assert_not campsite.valid?
    assert_includes campsite.errors[:registration_fee_cents], "must be greater than or equal to 0"
  end

  test "registration reimbursement details must be complete" do
    campsite = campsites(:yosemite_a)
    campsite.registration_reimbursed_at = Time.current

    assert_not campsite.valid?
    assert_includes campsite.errors[:registration_reimbursed_by], "must be selected"
    assert_includes campsite.errors[:registration_reimbursement_method], "must be selected"
    assert_includes campsite.errors[:registration_reimbursement_recorded_by], "must be selected"

    campsite.registration_reimbursed_by = users(:sam)
    campsite.registration_reimbursement_method = "venmo"
    campsite.registration_reimbursement_recorded_by = users(:alex)

    assert campsite.valid?
  end

  test "registration reimbursement method label is human readable" do
    campsite = campsites(:yosemite_a)

    campsite.registration_reimbursement_method = "stripe"

    assert_equal "Stripe", campsite.registration_reimbursement_method_label
  end

  test "checkout date must be after arrival date" do
    campsite = campsites(:yosemite_a)
    campsite.checkout_date = campsite.arrival_date

    assert_not campsite.valid?
    assert_includes campsite.errors[:checkout_date], "must be after the arrival date"
  end

  test "reservation dates must be within trip dates" do
    campsite = campsites(:yosemite_a)

    campsite.arrival_date = trips(:yosemite).start_date - 1.day
    assert_not campsite.valid?
    assert_includes campsite.errors[:arrival_date], "must be within the trip dates"

    campsite.arrival_date = trips(:yosemite).start_date
    campsite.checkout_date = trips(:yosemite).end_date + 1.day
    assert_not campsite.valid?
    assert_includes campsite.errors[:checkout_date], "must be within the trip dates"
  end

  test "summarizes campsite signup capacity" do
    campsite = campsites(:yosemite_a)
    create_campsite_signup!(campsite: campsite, user: users(:sam))

    assert_equal 1, campsite.confirmed_signup_count
    assert_equal 5, campsite.available_participant_capacity
  end

  test "creates parking spots from car capacity" do
    campsite = trips(:yosemite).campsites.create!(
      campground: campgrounds(:upper_pines),
      site_number: "A14",
      arrival_date: trips(:yosemite).start_date,
      checkout_date: trips(:yosemite).end_date,
      participant_capacity: 4,
      car_capacity: 3
    )

    assert_equal [ 1, 2, 3 ], campsite.parking_spots.pluck(:position)
    assert_equal [ "unassigned", "unassigned", "unassigned" ], campsite.parking_spots.pluck(:status)
  end

  test "syncs parking spots when car capacity changes" do
    campsite = campsites(:yosemite_a)

    campsite.update!(car_capacity: 3)
    assert_equal [ 1, 2, 3 ], campsite.parking_spots.pluck(:position)

    campsite.parking_spots.find_by!(position: 3).update!(status: "first_come_first_serve")
    campsite.update!(car_capacity: 2)

    assert_equal [ 1, 2 ], campsite.parking_spots.reload.pluck(:position)
  end

  test "does not reduce car capacity below assigned parking spots" do
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam))
    campsite.parking_spots.find_by!(position: 2).update!(status: "assigned", assigned_campsite_signup: signup)

    campsite.car_capacity = 1

    assert_not campsite.valid?
    assert_includes campsite.errors[:car_capacity], "cannot be below assigned parking spots"
  end

  test "counts assigned and first come first serve parking spots" do
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam))

    campsite.parking_spots.find_by!(position: 1).update!(status: "assigned", assigned_campsite_signup: signup)
    campsite.parking_spots.find_by!(position: 2).update!(status: "first_come_first_serve")

    assert_equal 1, campsite.assigned_parking_spot_count
    assert_equal 1, campsite.first_come_first_serve_parking_spot_count
    assert_equal 2, campsite.configured_parking_spot_count
  end

  test "campsite full status uses campsite signups" do
    campsite = campsites(:yosemite_a)
    campsite.participant_capacity.times do |index|
      create_campsite_signup!(campsite: campsite, user: User.create!(
        first_name: "Full",
        last_name: "Site#{index}",
        email: "full-site#{index}@example.com",
        password: "password"
      ))
    end

    assert campsite.capacity_full?
    assert_equal 0, campsite.available_participant_capacity
  end

  test "locked campsite requires waitlist even when space is open" do
    campsite = campsites(:yosemite_a)

    assert campsite.direct_signup_available?
    assert_not campsite.waitlist_signup_required?

    campsite.lock_signups!

    assert campsite.signups_locked?
    assert_not campsite.direct_signup_available?
    assert campsite.waitlist_signup_required?
  end

  test "campsite can be available for waitlist confirmation when party fits" do
    campsite = campsites(:yosemite_a)
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))

    assert campsite.available_for_waitlist_confirmation?(signup)

    campsite.participant_capacity.times do |index|
      create_campsite_signup!(campsite: campsite, user: User.create!(
        first_name: "Confirmed",
        last_name: "WaitlistFit#{index}",
        email: "confirmed-waitlist-fit-#{index}@example.com",
        password: "password"
      ))
    end

    assert_not campsite.reload.available_for_waitlist_confirmation?(signup)
  end

  test "destroy is blocked by active signups but detaches canceled signups" do
    campsite = campsites(:yosemite_a)
    active_signup = create_campsite_signup!(campsite: campsite, user: users(:sam))
    canceled_signup = create_campsite_signup!(campsite: campsite, user: users(:alex), status: "canceled")

    assert_not campsite.destroy
    assert_includes campsite.errors[:base], "Cannot delete campsite with participants signed up"
    assert_equal campsite, canceled_signup.reload.campsite

    active_signup.destroy!

    assert_difference "Campsite.count", -1 do
      assert_no_difference "CampsiteSignup.count" do
        campsite.destroy
      end
    end
    assert_nil canceled_signup.reload.campsite
  end
end
