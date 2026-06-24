require "test_helper"

class TripReadinessCompletionTest < ActiveSupport::TestCase
  test "requires a fixed completable task key" do
    completion = TripReadinessCompletion.new(
      trip: trips(:yosemite),
      task_key: "not_a_real_task",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    assert_not completion.valid?
    assert_includes completion.errors[:task_key], "is not included in the list"
  end

  test "allows each readiness task once per trip" do
    TripReadinessCompletion.create!(
      trip: trips(:yosemite),
      task_key: "add_photo_album_to_older_website",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    duplicate = TripReadinessCompletion.new(
      trip: trips(:yosemite),
      task_key: "add_photo_album_to_older_website",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:task_key], "has already been taken"
  end

  test "allows manual overrides for selected automatic readiness tasks" do
    completion = TripReadinessCompletion.new(
      trip: trips(:yosemite),
      task_key: "create_google_photo_album",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    assert completion.valid?
  end

  test "allows manual overrides for campsite readiness tasks on the same trip" do
    completion = TripReadinessCompletion.new(
      trip: trips(:yosemite),
      task_key: "campsite_#{campsites(:yosemite_b).id}_registration_number",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    assert completion.valid?
  end

  test "allows manual overrides for selected participant readiness tasks" do
    completion = TripReadinessCompletion.new(
      trip: trips(:yosemite),
      task_key: "all_confirmed_participants_signed_waiver",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    assert completion.valid?
  end

  test "allows manual overrides for campsite reimbursement readiness" do
    completion = TripReadinessCompletion.new(
      trip: trips(:yosemite),
      task_key: "all_campsites_reimbursed",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    assert completion.valid?
  end

  test "rejects campsite readiness tasks for another trip" do
    completion = TripReadinessCompletion.new(
      trip: trips(:jtree),
      task_key: "campsite_#{campsites(:yosemite_b).id}_registration_number",
      completed_at: Time.current,
      completed_by: users(:alex)
    )

    assert_not completion.valid?
    assert_includes completion.errors[:task_key], "is not included in the list"
  end
end
