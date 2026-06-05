require "test_helper"

class Admin::TripReimbursementsControllerTest < ActionDispatch::IntegrationTest
  test "admin can record reimbursement" do
    assert_difference "TripReimbursement.count", 1 do
      post admin_trip_trip_reimbursements_url(trips(:yosemite)), params: {
        trip_reimbursement: {
          recipient_name: "Alex Rivera",
          amount: "42.50",
          payment_method: "venmo",
          paid_on: "2026-06-01",
          note: "Propane and breakfast"
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    reimbursement = TripReimbursement.order(:created_at).last
    assert_equal trips(:yosemite), reimbursement.trip
    assert_equal "Alex Rivera", reimbursement.recipient_name
    assert_equal 4250, reimbursement.amount_cents
    assert_equal "venmo", reimbursement.payment_method
  end

  test "admin can update reimbursement" do
    reimbursement = trips(:yosemite).trip_reimbursements.create!(
      recipient_name: "Alex Rivera",
      amount_cents: 2000,
      payment_method: "zelle",
      paid_on: Date.new(2026, 6, 1)
    )

    patch admin_trip_trip_reimbursement_url(trips(:yosemite), reimbursement), params: {
      trip_reimbursement: {
        recipient_name: "Sam Lee",
        amount: "25",
        payment_method: "cash",
        paid_on: "2026-06-02",
        note: "Firewood"
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite))
    reimbursement.reload
    assert_equal "Sam Lee", reimbursement.recipient_name
    assert_equal 2500, reimbursement.amount_cents
    assert_equal "cash", reimbursement.payment_method
  end

  test "admin can remove reimbursement" do
    reimbursement = trips(:yosemite).trip_reimbursements.create!(
      recipient_name: "Alex Rivera",
      amount_cents: 2000,
      payment_method: "zelle",
      paid_on: Date.new(2026, 6, 1)
    )

    assert_difference "TripReimbursement.count", -1 do
      delete admin_trip_trip_reimbursement_url(trips(:yosemite), reimbursement)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
  end
end
