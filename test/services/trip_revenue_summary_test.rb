require "test_helper"

class TripRevenueSummaryTest < ActiveSupport::TestCase
  test "summarizes campsite revenue one time requests expenses and final total" do
    trip = trips(:yosemite)
    campsites(:yosemite_a).update!(registration_fee: "84.25")
    campsites(:yosemite_b).update!(registration_fee: "92.50")
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
      reason: "Firewood",
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
    assert_equal [ "Upper Pines site A12 registration fee", "Upper Pines site A13 registration fee" ], summary.campsite_registration_fee_lines.map(&:label)
    assert_equal [ 8_425, 9_250 ], summary.campsite_registration_fee_lines.map(&:fee_cents)
    assert_equal 12_000, summary.campsite_revenue_cents
    assert_equal 2_500, summary.one_time_payment_requests_cents
    assert_equal 14_500, summary.total_revenue_cents
    assert_equal 1_000, summary.trip_expense_refund_cents
    assert_equal [ "Sam Lee" ], summary.trip_expense_lines.map(&:participant_name)
    assert_equal [ "Firewood" ], summary.trip_expense_lines.map(&:reason)
    assert_equal [ 1_000 ], summary.trip_expense_lines.map(&:amount_cents)
    assert_equal [ "transaction-payment-#{campsite_a_payment.id}" ], summary.trip_expense_lines.map(&:transaction_anchor)
    assert_equal 17_675, summary.campsite_registration_fee_cents
    assert_equal 18_675, summary.total_expense_cents
    assert_equal(-4_175, summary.final_total_cents)
  end
end
