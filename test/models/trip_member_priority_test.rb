require "test_helper"

class TripMemberPriorityTest < ActiveSupport::TestCase
  test "first publication starts the configured camping window instead of draft creation" do
    travel_to TripCalendar::TIME_ZONE.local(2026, 10, 16, 10) do
      trip = trips(:jtree)
      trip.update!(created_at: 6.months.ago)
      assert_nil trip.first_published_at
      assert_nil trip.members_only_until
      trip.update!(status: "published")
      assert_equal Time.current, trip.first_published_at
      assert_equal 15.days.from_now, trip.members_only_until
      assert trip.member_priority_active?
      assert trip.member_priority_blocks?(users(:sam))
      assert trip.member_priority_blocks?(nil)
      assert_not trip.member_priority_blocks?(users(:alex))
      assert trip.member_priority_active?(now: trip.members_only_until - 1.second)
      assert_not trip.member_priority_active?(now: trip.members_only_until)
    end
  end

  test "settings edits and republishing never reset an announced opening" do
    trip = trips(:jtree)
    trip.update!(status: "published")
    opening = trip.members_only_until
    published = trip.first_published_at
    SiteSetting.current.update!(camping_member_priority_days: 30)
    travel 2.days do
      trip.update!(name: "New name", status: "draft")
      assert_not trip.member_priority_active?
      trip.update!(status: "published")
      assert_equal opening, trip.reload.members_only_until
      assert_equal published, trip.first_published_at
    end
  end

  test "new published camping trips use custom duration and zero disables it" do
    [ 7, 0 ].each do |days|
      SiteSetting.current.update!(camping_member_priority_days: days)
      trip = Trip.create!(name: "Granite weekend", location: "Yosemite", start_date: Date.current, end_date: Date.tomorrow, status: "published")
      assert trip.first_published_at
      assert_equal days.positive?, trip.member_priority_active?
      assert_nil trip.members_only_until if days.zero?
      assert_equal days, (trip.members_only_until.to_date - trip.first_published_at.to_date).to_i if days.positive?
    end
  end

  test "legacy public trips stay open on edits and republishing" do
    trip = trips(:yosemite)
    trip.update!(name: "Existing camping trip", status: "draft")
    trip.update!(status: "published")
    assert_nil trip.members_only_until
    assert_not trip.member_priority_active?
  end

  test "non camping and archived trips have no active priority window" do
    trip = trips(:jtree)
    trip.update!(trip_type: "gym_outing", participant_capacity: 10, meeting_time: "18:00", status: "published")
    assert trip.first_published_at
    assert_nil trip.members_only_until
    trip.update!(trip_type: "camping", members_only_until: 15.days.from_now, status: "archived")
    assert_not trip.member_priority_active?
  end

  test "opening keeps the local publication time across daylight saving changes" do
    travel_to TripCalendar::TIME_ZONE.local(2026, 10, 25, 10) do
      trip = trips(:jtree)
      trip.update!(status: "published")
      assert_equal TripCalendar::TIME_ZONE.local(2026, 11, 9, 10), trip.members_only_until
      assert_includes trip.member_priority_message, "November 9, 2026 at 10:00 AM PST"
    end
  end
end
