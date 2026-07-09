require "test_helper"

class Admin::TripTransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

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
      stripe_processing_fee_cents: 117,
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
      refunded_by: users(:alex),
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
      waived_reason: "Scholarship",
      created_by: users(:alex)
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
    assert_select "table.transactions-table[data-controller='transaction-anchor']" do
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
      assert_includes ledger_statuses, "Partially Refunded"
      assert_equal 2, ledger_statuses.count("Paid")
      assert ledger_rows.any? { |row| row.at_css(".transaction-status.warning-status")&.text&.strip == "Partially Refunded" }
      assert_not_includes ledger_statuses, "Pending"
      assert_not_includes css_select("thead").first.text, "Refunded?"
      assert_not_includes css_select("thead").first.text, "Campsite ID"
      assert_not_includes css_select("thead").first.text, "Source"
      assert_not_includes css_select("thead").first.text, "Refund"
      assert_select "button", text: "View", count: 3
      assert_select "button", text: "Issue Refund", count: 3
      assert_select "tr#transaction-payment-#{stripe_payment.id}"
    end
    assert_select "dialog.transaction-details-modal", count: 3
    detail_sections = css_select("dialog.transaction-details-modal").first.css(".transaction-details-list")
    assert_equal 2, detail_sections.size
    assert_equal [
      "Participant",
      "Status",
      "Paid at",
      "Admin created",
      "Waived By",
      "Waived reason",
      "Created at",
      "Updated at",
      "Note"
    ], detail_sections.first.css("dt").map { |label| label.text.strip }
    assert_equal [
      "Amount",
      "Amount Refunded",
      "Remaining refundable",
      "Source",
      ""
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
      assert_select ".transaction-status.warning-status", text: "Partially Refunded"
      assert_select "dt", text: "Stripe payment intent", count: 0
      assert_select "dt", text: "Source"
      assert_select "a[href='https://dashboard.stripe.com/acct_test_123/test/payments/pi_ledger_123']", text: "Stripe"
      assert_select "dt", text: "Stripe processing fee"
      assert_select "dd", text: "-$1.17"
      assert_select "dt", text: "Net amount"
      assert_select "dd", text: "$98.83"
      assert_select "dt", text: "Amount Refunded"
      assert_select "dd", text: "$10.00"
      assert_select ".transaction-refund-action-row dt", text: ""
      assert_select ".transaction-refund-action-row button.danger.secondary", text: "Issue Refund"
      assert_select ".transaction-fee-details legend", "Fee details"
      stripe_modal = css_select("dialog.transaction-details-modal").find do |dialog|
        dialog.at_css("a[href='https://dashboard.stripe.com/acct_test_123/test/payments/pi_ledger_123']")
      end
      stripe_detail_sections = stripe_modal.at_css(".transaction-details-sections").children.select do |node|
        node.element? && node["class"].to_s.split.include?("transaction-details-list")
      end
      assert_equal [
        "Amount",
        "Amount Refunded",
        "Remaining refundable",
        "Source",
        "Stripe processing fee",
        "Net amount",
        ""
      ], stripe_detail_sections.last.children.select(&:element?).map { |row| row.children.find { |child| child.element? && child.name == "dt" }&.text&.strip }
      fee_table = stripe_modal.at_css(".transaction-fee-table")
      assert_equal [
        "Participant",
        "First 2 nights",
        "Additional nights",
        "Total"
      ], fee_table.css("thead th").map { |header| header.text.strip }
      fee_rows = fee_table.css("tbody tr").map { |row| row.text.squish }
      assert_equal 3, fee_rows.size
      assert_includes fee_rows, "Sam Lee $30.00 $10.00 $40.00"
      assert_includes fee_rows, "Jordan Guest $30.00 $10.00 $40.00"
      assert_includes fee_rows, "Mini Lee $15.00 $5.00 $20.00"
      assert_select ".transaction-fee-total", text: "$100.00"
      assert_select ".transaction-fee-details", text: /Total:/, count: 0
      assert_select "h3", "Refunds"
      assert_select ".transaction-refunds-table" do
        assert_select "th", text: "Amount"
        assert_select "th", text: "Refunded At"
        assert_select "th", text: "Refunded By"
        assert_select "th", text: "Type"
        assert_select "th", text: "Reason"
        assert_select "th", text: "Status", count: 0
        assert_select "th", text: "Initiated By", count: 0
        assert_select "th", text: "Failure", count: 0
        assert_select "th", text: "Stripe Refund ID", count: 0
      end
      assert_select "td", text: "Admin", count: 0
      assert_select "td", text: "Alex Rivera"
      assert_select "td", text: "Automatic"
      assert_select "code", text: "re_ledger_123", count: 0
      assert_select "code", text: "re_failed_123", count: 0
    end
    waived_modal = css_select("dialog.transaction-details-modal").find do |dialog|
      dialog.css("dt").any? { |term| term.text.strip == "Waived reason" } &&
        dialog.css("dd").any? { |definition| definition.text.strip == "Scholarship" }
    end
    assert waived_modal
    assert_equal "Waived By", waived_modal.css("dt").find { |term| term.text.strip == "Waived By" }.text.strip
    assert_equal "Alex Rivera", waived_modal.css("dd").find { |definition| definition.text.strip == "Alex Rivera" }.text.strip
    assert_select "div[data-modal-disable-autofocus-value='true'] dialog.refund-modal"
    assert_select "dialog.refund-modal" do
      assert_select "h2", "Refund payment"
      assert_select "dt", text: "Participant"
      assert_select "dd", text: "Sam Lee"
      assert_select "dt", text: "Remaining refundable"
      assert_select "dd", text: "$90.00"
      assert_select "label[for='refund_#{stripe_payment.id}_amount']", text: /Refund amount/
      assert_select "label[for='refund_#{stripe_payment.id}_amount'] .required-marker", text: "*"
      assert_select ".refund-amount-field .currency-field"
      assert_select "input[name='refund[amount]'][required]"
      assert_select "input[name='refund[amount]'][value='0.00']"
      assert_select "label[for='refund_#{stripe_payment.id}_reason']", text: /Reason for refund/
      assert_select "label[for='refund_#{stripe_payment.id}_reason'] .required-marker", text: "*"
      assert_select "textarea[name='refund[reason]'][required]"
      assert_select "input[type='checkbox'][name='refund[trip_expense]'][value='1']"
      assert_select "label[for='refund_#{stripe_payment.id}_trip_expense']", text: "This was for a trip expense (ex: firewood)"
      assert_select "input[type='submit'][value='Issue Refund']"
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

  test "refund controls move into details modal and disable non refundable payments" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_refundable"
    )
    signup.payments.create!(
      source: "stripe",
      status: "refunded",
      amount_cents: 2000,
      refunded_amount_cents: 2000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_refunded"
    )
    signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 0,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_zero"
    )
    signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 3000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )

    get admin_trip_transactions_url(trip)

    assert_response :success
    assert_select "dialog.refund-modal", count: 1
    assert_select "table.transactions-table thead th", text: "Refund", count: 0
    assert_select "button", text: "Issue Refund", count: 4
    assert_select "button[disabled]", text: "Issue Refund", count: 3
    assert_select ".transaction-status.danger-status", text: "Refunded"
  end

  test "admin can issue partial stripe refund from transactions page" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_partial_refund"
    )
    stripe_refund = Struct.new(:id, :status).new("re_partial_refund", "succeeded")

    with_fake_stripe_refund(stripe_refund) do |calls|
      post refund_admin_trip_transaction_url(trip, payment), params: {
        refund: {
          amount: "4.50",
          reason: "participant schedule change"
        }
      }

      assert_equal 1, calls.size
      assert_equal "pi_partial_refund", calls.first[:payment_intent]
      assert_equal 450, calls.first[:amount]
    end

    assert_redirected_to admin_trip_transactions_url(trip)
    assert payment.reload.partially_refunded?
    assert_equal 450, payment.refunded_amount_cents
    refund = payment.refunds.sole
    assert refund.succeeded?
    assert refund.admin_initiated_by?
    assert_equal users(:alex), refund.refunded_by
    assert_equal "admin_created", refund.refund_type
    assert_equal "participant schedule change", refund.reason
    assert_equal "re_partial_refund", refund.stripe_refund_id
  end

  test "admin can mark transactions page refund as trip expense" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_trip_expense_refund"
    )
    stripe_refund = Struct.new(:id, :status).new("re_trip_expense_refund", "succeeded")

    with_fake_stripe_refund(stripe_refund) do
      post refund_admin_trip_transaction_url(trip, payment), params: {
        refund: {
          amount: "3.00",
          reason: "firewood",
          trip_expense: "1"
        }
      }
    end

    refund = payment.refunds.sole
    assert_equal "trip_expense", refund.refund_type
    assert_equal "Trip Expense", refund.refund_type_label
  end

  test "admin can issue full remaining stripe refund from transactions page" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_full_refund"
    )
    stripe_refund = Struct.new(:id, :status).new("re_full_refund", "succeeded")

    with_fake_stripe_refund(stripe_refund) do
      post refund_admin_trip_transaction_url(trip, payment), params: {
        refund: {
          amount: "10.00",
          reason: "trip canceled"
        }
      }
    end

    assert_redirected_to admin_trip_transactions_url(trip)
    assert payment.reload.refunded?
    assert_equal 1000, payment.refunded_amount_cents
  end

  test "refund rejects invalid transactions page requests before calling stripe" do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_invalid_refund"
    )
    manual_payment = signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 1000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )

    with_fake_stripe_refund do |calls|
      post refund_admin_trip_transaction_url(trip, payment), params: { refund: { amount: "11.00", reason: "too much" } }
      post refund_admin_trip_transaction_url(trip, payment), params: { refund: { amount: "1.00", reason: "" } }
      post refund_admin_trip_transaction_url(trip, manual_payment), params: { refund: { amount: "1.00", reason: "manual" } }

      assert_empty calls
    end

    assert_equal 0, payment.reload.refunded_amount_cents
    assert_equal 0, manual_payment.reload.refunded_amount_cents
  end

  test "refund rejects deleted trips before calling stripe" do
    trip = trips(:jtree)
    signup = create_campsite_signup!(campsite: campsites(:jtree_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_deleted_trip_refund"
    )
    trip.soft_delete!

    with_fake_stripe_refund do |calls|
      post refund_admin_trip_transaction_url(trip, payment), params: { refund: { amount: "1.00", reason: "deleted trip" } }

      assert_empty calls
    end

    assert_redirected_to admin_trip_transactions_url(trip)
    assert_equal 0, payment.reload.refunded_amount_cents
  end

  test "logged out admin refund redirects to login before calling stripe" do
    delete session_url
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_logged_out_refund"
    )

    with_fake_stripe_refund do |calls|
      post refund_admin_trip_transaction_url(trip, payment), params: { refund: { amount: "1.00", reason: "logged out" } }

      assert_empty calls
    end

    assert_redirected_to new_session_url
    assert_equal 0, payment.reload.refunded_amount_cents
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

  def with_fake_stripe_refund(stripe_refund = Struct.new(:id, :status).new("re_test", "succeeded"))
    original_create = Stripe::Refund.method(:create)
    calls = []
    Stripe::Refund.define_singleton_method(:create) do |params|
      calls << params
      stripe_refund
    end
    yield calls
  ensure
    Stripe::Refund.define_singleton_method(:create, original_create)
  end
end
