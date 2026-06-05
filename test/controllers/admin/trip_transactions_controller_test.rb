require "test_helper"

class Admin::TripTransactionsControllerTest < ActionDispatch::IntegrationTest
  test "shows completed payments with payment and refund details in modal" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(
      campsite: campsite,
      user: users(:sam),
      arrival_date: campsite.arrival_date,
      checkout_date: campsite.arrival_date + 3.days
    )
    adult_guest = User.create!(
      first_name: "Jordan",
      last_name: "Guest",
      email: "jordan-guest@example.com",
      password: "password"
    )
    create_campsite_signup!(
      campsite: campsite,
      user: adult_guest,
      guest_of_signup: signup,
      guest_position: 1,
      arrival_date: signup.arrival_date,
      checkout_date: signup.checkout_date
    )
    signup.campsite_signup_minors.create!(
      first_name: "Mini",
      last_name: "Lee",
      age: 12,
      relationship: "Child"
    )
    stripe_payment = signup.payments.create!(
      source: "stripe",
      status: "partially_refunded",
      amount_cents: 10000,
      refunded_amount_cents: 1000,
      paid_at: Time.zone.local(2026, 6, 1, 9, 0),
      stripe_payment_intent_id: "pi_ledger_123",
      pricing_snapshot: {
        "amount_cents" => 10000,
        "adult_count" => 2,
        "counted_minor_count" => 1,
        "free_minor_count" => 0,
        "night_count" => 3,
        "extra_night_count" => 1,
        "first_two_nights_fee_cents" => 3000,
        "extra_night_fee_cents" => 1000,
        "minor_fee_cents" => 1500,
        "minor_extra_night_fee_cents" => 500,
        "uncounted_minor_age_limit" => 10
      }
    )
    stripe_payment.refunds.create!(
      amount_cents: 1000,
      status: "succeeded",
      initiated_by: "admin",
      refunded_at: Time.zone.local(2026, 6, 2, 10, 0),
      stripe_refund_id: "re_ledger_123"
    )
    signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 3000,
      manual_payment_method: "cash",
      manual_paid_at: Time.zone.local(2026, 6, 1, 8, 0),
      paid_at: Time.zone.local(2026, 6, 1, 8, 0)
    )
    signup.payments.create!(
      source: "waived",
      status: "waived",
      amount_cents: 0,
      waived_reason: "Scholarship"
    )
    signup.payments.create!(
      source: "stripe",
      status: "pending",
      amount_cents: 5000
    )
    stripe_payment.refunds.create!(
      amount_cents: 500,
      status: "failed",
      initiated_by: "participant",
      stripe_refund_id: "re_failed_123"
    )

    with_env("STRIPE_ACCOUNT_ID" => "acct_test_123") do
      get admin_trip_transactions_url(trip)
    end

    assert_response :success
    assert_select "h2", "Transactions"
    assert_select ".panel", count: 1
    assert_select ".panel", text: /Payments and refunds for/, count: 0
    assert_select "a[href='#{admin_trip_path(trip)}']", text: "Back to trip"
    assert_select "table.transactions-table" do
      assert_equal [
        "Participant",
        "Amount Paid",
        "Status",
        "Paid At",
        "Details"
      ], css_select("thead").first.css("th").map { |header| header.text.strip }
      ledger_rows = css_select("tbody").first.children.select { |child| child.element? && child.name == "tr" }
      assert_equal 3, ledger_rows.size
      assert_select "tbody tr.refunded-transaction-row", count: 0
      assert_select "td", text: "$100.00"
      assert_select "td", text: "$30.00"
      assert_select "td", text: "$0.00"
      assert_select "td", text: "Sam Lee"
      ledger_statuses = ledger_rows.map do |row|
        row.children.select { |child| child.element? && child.name == "td" }[2].text.strip
      end
      assert_includes ledger_statuses, "Refunded"
      assert_equal 2, ledger_statuses.count("Paid")
      assert ledger_rows.any? { |row| row.at_css(".transaction-status.danger-status")&.text&.strip == "Refunded" }
      assert_not_includes ledger_statuses, "Pending"
      assert_not_includes css_select("thead").first.text, "Refunded?"
      assert_not_includes css_select("thead").first.text, "Campsite ID"
      assert_not_includes css_select("thead").first.text, "Source"
      assert_select "button", text: "View", count: 3
    end
    assert_select "dialog.transaction-details-modal", count: 3
    detail_sections = css_select("dialog.transaction-details-modal").first.css(".transaction-details-list")
    assert_equal 2, detail_sections.size
    assert_equal [
      "Participant",
      "Status",
      "Paid at",
      "Admin created",
      "Waived reason",
      "Created at",
      "Updated at",
      "Note"
    ], detail_sections.first.css("dt").map { |label| label.text.strip }
    assert_equal [
      "Amount",
      "Amount Refunded",
      "Remaining refundable",
      "Source"
    ], detail_sections.last.css("dt").map { |label| label.text.strip }
    assert_select "dialog.transaction-details-modal", text: /Payment details/ do
      assert_select "dt", text: "Payment ID", count: 0
      assert_select "dt", text: "Currency", count: 0
      assert_select "dt", text: "Manual paid at", count: 0
      assert_select "dt", text: "Manual payment method", count: 0
      assert_select "dt", text: "Previous signup status", count: 0
      assert_select "dt", text: "Expires at", count: 0
      assert_select "dt", text: "Expired at", count: 0
      assert_select "dt", text: "Campsite ID", count: 0
      assert_select "dt", text: "Stripe checkout session ID", count: 0
      assert_select "dt", text: "Created by", count: 0
      assert_select "dt", text: "Admin created"
      assert_select "dd", text: "No"
      assert_select ".transaction-status.danger-status", text: "Refunded"
      assert_select "dt", text: "Stripe payment intent", count: 0
      assert_select "dt", text: "Source"
      assert_select "a[href='https://dashboard.stripe.com/acct_test_123/test/payments/pi_ledger_123']", text: "Stripe"
      assert_select "dt", text: "Amount Refunded"
      assert_select "dd", text: "$10.00"
      assert_select ".transaction-fee-details legend", "Fee details"
      stripe_modal = css_select("dialog.transaction-details-modal").find do |dialog|
        dialog.at_css("a[href='https://dashboard.stripe.com/acct_test_123/test/payments/pi_ledger_123']")
      end
      fee_table = stripe_modal.at_css(".transaction-fee-table")
      assert_equal [
        "Participant",
        "First 2 nights",
        "Additional nights",
        "Total"
      ], fee_table.css("thead th").map { |header| header.text.strip }
      fee_rows = fee_table.css("tbody tr").map { |row| row.text.squish }
      assert_equal 3, fee_rows.size
      assert_includes fee_rows, "You $30.00 $10.00 $40.00"
      assert_includes fee_rows, "Adult 2 $30.00 $10.00 $40.00"
      assert_includes fee_rows, "Minor 1 (age 12) $15.00 $5.00 $20.00"
      assert_select ".transaction-fee-total", text: "$100.00"
      assert_select ".transaction-fee-details", text: /Total:/, count: 0
      assert_select "h3", "Refunds"
      assert_select "th", text: "Initiated By"
      assert_select "th", text: "Stripe Refund ID", count: 0
      assert_select "td", text: "Admin"
      assert_select "code", text: "re_ledger_123", count: 0
      assert_select "code", text: "re_failed_123", count: 0
    end
  end

  test "transactions page is available for deleted trips" do
    trip = trips(:jtree)
    trip.soft_delete!

    get admin_trip_transactions_url(trip)

    assert_response :success
    assert_select ".deleted-trip-banner", text: /This trip has been deleted/
    assert_select "form[action='#{restore_admin_trip_path(trip)}'] button", text: "Restore trip"
  end

  private

  def with_env(values)
    originals = values.keys.index_with { |key| ENV[key] }
    values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    originals.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
