require "test_helper"

class TripTest < ActiveSupport::TestCase
  test "requires core fields" do
    trip = Trip.new

    assert_not trip.valid?
    assert_includes trip.errors[:name], "can't be blank"
    assert_includes trip.errors[:location], "can't be blank"
    assert_includes trip.errors[:start_date], "can't be blank"
    assert_includes trip.errors[:end_date], "can't be blank"
  end

  test "requires known status" do
    trip = trips(:yosemite)

    assert_raises ArgumentError do
      trip.status = "cancelled"
    end
  end

  test "requires end date on or after start date" do
    trip = trips(:yosemite)
    trip.end_date = trip.start_date - 1.day

    assert_not trip.valid?
    assert_includes trip.errors[:end_date], "must be on or after the start date"
  end

  test "group campfire campsite must belong to the trip" do
    trip = trips(:yosemite)
    trip.group_campfire_campsite = campsites(:jtree_a)

    assert_not trip.valid?
    assert_includes trip.errors[:group_campfire_campsite], "must belong to this trip"
  end

  test "group fire night must be a known day when set" do
    trip = trips(:yosemite)
    trip.group_fire_night = "funday"

    assert_not trip.valid?
    assert_includes trip.errors[:group_fire_night], "is not included in the list"

    trip.group_fire_night = "none"
    assert trip.valid?

    trip.group_fire_night = "sunday"
    assert trip.valid?
  end

  test "published trip can be created before campsite coordinator is known" do
    trip = trips(:yosemite)
    trip.campsite_coordinator = nil

    assert trip.valid?
  end

  test "draft and archived trips can also omit campsite coordinator" do
    trip = trips(:jtree)
    trip.campsite_coordinator = nil

    trip.status = "draft"
    assert trip.valid?

    trip.status = "archived"
    assert trip.valid?
  end

  test "summarizes campsite capacity" do
    trip = trips(:yosemite)

    assert_equal 2, trip.campsite_count
    assert_equal 10, trip.total_participant_capacity
    assert_equal 3, trip.total_car_capacity
  end

  test "summarizes available participant capacity" do
    trip = trips(:yosemite)
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_equal 9, trip.available_participant_capacity
  end

  test "maps day trip climbing types to climbing helpers" do
    trip = Trip.new(climbing_types: [ "sport" ])
    assert trip.sport_climbing?
    assert_not trip.trad_climbing?
    assert_not trip.bouldering?

    trip.climbing_types = [ "trad" ]
    assert_not trip.sport_climbing?
    assert trip.trad_climbing?
    assert_not trip.bouldering?

    trip.climbing_types = [ "sport", "trad", "bouldering" ]
    assert trip.sport_climbing?
    assert trip.trad_climbing?
    assert trip.bouldering?
  end

  test "capacity count includes minors at the age limit and excludes younger minors" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Young", last_name: "Minor", age: 12, relationship: "Child")
    signup.campsite_signup_minors.create!(first_name: "Teen", last_name: "Minor", age: 13, relationship: "Child")

    assert_equal 2, trip.confirmed_signup_count
    assert_equal 1, trip.confirmed_uncounted_minor_count
    assert_equal 8, trip.available_participant_capacity
  end

  test "capacity count uses configured uncounted minor age limit" do
    SiteSetting.current.update!(uncounted_minor_age_limit: 15)
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Teen", last_name: "Minor", age: 14, relationship: "Child")

    assert_equal 1, trip.confirmed_signup_count
    assert_equal 1, trip.confirmed_uncounted_minor_count
    assert_equal 9, trip.available_participant_capacity
  ensure
    SiteSetting.current.update!(uncounted_minor_age_limit: 13)
  end

  test "knows when capacity reaches the almost full threshold" do
    trip = trips(:yosemite)

    7.times do |index|
      campsite = index < 6 ? campsites(:yosemite_a) : campsites(:yosemite_b)
      create_campsite_signup!(campsite:, user: User.create!(
        first_name: "Almost",
        last_name: "Full#{index}",
        email: "almost-full#{index}@example.com",
        password: "password"
      ))
    end

    assert_not trip.almost_full?

    create_campsite_signup!(campsite: campsites(:yosemite_b), user: User.create!(
      first_name: "Almost",
      last_name: "FullThreshold",
      email: "almost-full-threshold@example.com",
      password: "password"
    ))

    assert trip.almost_full?
    assert_not trip.capacity_full?
  end

  test "waitlist priority favors members before signup date" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    campsite.lock_signups!
    non_member = User.create!(
      first_name: "Older",
      last_name: "Guest",
      email: "older-guest@example.com",
      password: "password",
      member: false
    )
    member = User.create!(
      first_name: "Later",
      last_name: "Member",
      email: "later-member@example.com",
      password: "password",
      member: true
    )
    older_signup = create_waitlisted_signup!(trip: trip, user: non_member, created_at: 2.days.ago)
    member_signup = create_waitlisted_signup!(trip: trip, user: member, created_at: 1.day.ago)

    assert_equal [ member_signup, older_signup ], trip.waitlisted_signups.to_a

    trip.mark_next_waitlisted_signup_eligible!

    assert member_signup.reload.waitlist_eligible?
    assert_not older_signup.reload.waitlist_eligible?
  end

  test "waitlist priority keeps member date order" do
    trip = trips(:yosemite)
    older_member = User.create!(
      first_name: "Older",
      last_name: "Member",
      email: "older-member@example.com",
      password: "password",
      member: true
    )
    later_member = User.create!(
      first_name: "Later",
      last_name: "Member",
      email: "later-member-order@example.com",
      password: "password",
      member: true
    )
    older_signup = create_waitlisted_signup!(trip: trip, user: older_member, created_at: 2.days.ago)
    later_signup = create_waitlisted_signup!(trip: trip, user: later_member, created_at: 1.day.ago)

    assert_equal [ older_signup, later_signup ], trip.waitlisted_signups.to_a
  end

  test "waitlist confirmation campsites require allowed signup status" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    signup = create_waitlisted_signup!(trip: trip, user: users(:sam))

    assert_empty trip.waitlist_confirmation_campsites_for(signup)

    signup.update!(waitlist_eligible_at: Time.current)

    assert_equal trip.campsites.map(&:id).sort, trip.waitlist_confirmation_campsites_for(signup).map(&:id).sort
  end

  test "waitlisted guests are summarized under primary signup" do
    trip = trips(:yosemite)
    primary_signup = create_waitlisted_signup!(trip: trip, user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "trip-waitlist-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    create_waitlisted_signup!(trip: trip, user: guest_user, guest_of_signup: primary_signup, guest_position: 1)

    assert_equal [ primary_signup ], trip.waitlisted_signups.to_a
    assert_equal "Sam L. + Gina G.", primary_signup.public_waitlist_name
  end

  test "destroy is blocked by active signups and soft delete preserves canceled history" do
    trip = trips(:yosemite)
    active_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_not trip.destroy
    assert_includes trip.errors[:base], "Cannot delete a trip with participants signed up"
    assert CampsiteSignup.exists?(active_signup.id)

    history_trip = Trip.create!(
      name: "Canceled History Trip",
      location: "Yosemite Valley, CA",
      start_date: Date.new(2026, 7, 10),
      end_date: Date.new(2026, 7, 12),
      status: "draft"
    )
    canceled_signup = CampsiteSignup.create!(trip: history_trip, user: users(:alex), status: "canceled")
    payment = canceled_signup.payments.create!(source: "manual", status: "refunded", amount_cents: 1000, refunded_amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

    assert_no_difference "Trip.count" do
      assert_no_difference "CampsiteSignup.count" do
        history_trip.soft_delete!
      end
    end
    assert history_trip.deleted?
    assert CampsiteSignup.exists?(canceled_signup.id)
    assert CampsiteSignupPayment.exists?(payment.id)

    history_trip.restore!
    assert_not history_trip.deleted?
  end

  test "waitlist confirmation uses full party capacity including guests" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    fill_count = campsite.participant_capacity - 1
    fill_count.times do |index|
      create_campsite_signup!(campsite: campsite, user: User.create!(
        first_name: "Confirmed",
        last_name: "GuestCapacity#{index}",
        email: "confirmed-guest-capacity-#{index}@example.com",
        password: "password"
      ))
    end
    campsite.lock_signups!
    primary_signup = create_waitlisted_signup!(trip: trip, user: users(:sam), waitlist_eligible_at: Time.current)
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "trip-capacity-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    create_waitlisted_signup!(trip: trip, user: guest_user, guest_of_signup: primary_signup, guest_position: 1)

    confirmation_campsites = trip.waitlist_confirmation_campsites_for(primary_signup)
    assert_not_includes confirmation_campsites, campsite
    assert_includes confirmation_campsites, campsites(:yosemite_b)
  end

  test "waitlist eligibility skips parties that cannot fit open capacity" do
    trip = trips(:yosemite)
    trip.campsites.each do |campsite|
      fill_count = campsite.participant_capacity - 1
      fill_count.times do |index|
        create_campsite_signup!(campsite: campsite, user: User.create!(
          first_name: "Confirmed",
          last_name: "SkipFit#{campsite.id}#{index}",
          email: "confirmed-skip-fit-#{campsite.id}-#{index}@example.com",
          password: "password"
        ))
      end
      campsite.lock_signups!
    end
    large_party_user = User.create!(
      first_name: "Large",
      last_name: "Party",
      email: "large-party@example.com",
      password: "password",
      member: true
    )
    small_party_user = User.create!(
      first_name: "Small",
      last_name: "Party",
      email: "small-party@example.com",
      password: "password",
      member: false
    )
    large_party_signup = create_waitlisted_signup!(trip: trip, user: large_party_user, created_at: 2.days.ago)
    large_party_signup.campsite_signup_minors.create!(first_name: "Teen", last_name: "Party", age: 13, relationship: "Child")
    small_party_signup = create_waitlisted_signup!(trip: trip, user: small_party_user, created_at: 1.day.ago)

    trip.mark_next_waitlisted_signup_eligible!

    assert_not large_party_signup.reload.waitlist_eligible?
    assert small_party_signup.reload.waitlist_eligible?
  end
end
