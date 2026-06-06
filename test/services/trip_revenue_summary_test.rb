require "test_helper"

class TripRevenueSummaryTest < ActiveSupport::TestCase
  test "summarizes campsite revenue one time requests expenses and final total" do
    trip = trips(:yosemite)
    campsite_a_payment = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam)).payments.create!(
      source: "stripe",
      status: "partially_refunded",
      amount_cents: 10_000,
      refunded_amount_cents: 3_000,
      paid_at: Time.current
    )
    campsite_a_payment.refunds.create!(
      amount_cents: 2_000,
      status: "succeeded",
      initiated_by: "admin",
      refund_type: "admin_created",
      source: "stripe",
      currency: "usd"
    )
    campsite_a_payment.refunds.create!(
      amount_cents: 1_000,
      status: "succeeded",
      initiated_by: "admin",
      refund_type: "trip_expense",
      source: "stripe",
      currency: "usd"
    )
    campsite_b_user = User.create!(first_name: "Bri", last_name: "Crag", email: "bri-crag@example.com", password: "password")
    create_campsite_signup!(campsite: campsites(:yosemite_b), user: campsite_b_user).payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 4_000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
    trip.trip_payment_requests.create!(
      first_name: "Riley",
      last_name: "Stone",
      email: "riley@example.com",
      amount_cents: 2_500,
      reason: "Extra permit",
      status: "paid",
      paid_at: Time.current
    )

    summary = TripRevenueSummary.call(trip)

    assert_equal [ "Upper Pines site A12", "Upper Pines site A13" ], summary.campsite_lines.map(&:label)
    assert_equal 10_000, summary.campsite_lines.first.paid_cents
    assert_equal 2_000, summary.campsite_lines.first.refund_cents
    assert_equal 8_000, summary.campsite_lines.first.net_cents
    assert_equal 4_000, summary.campsite_lines.second.net_cents
    assert_equal 12_000, summary.campsite_revenue_cents
    assert_equal 2_500, summary.one_time_payment_requests_cents
    assert_equal 14_500, summary.total_revenue_cents
    assert_equal 1_000, summary.trip_expense_refund_cents
    assert_equal 13_500, summary.final_total_cents
  end
end
