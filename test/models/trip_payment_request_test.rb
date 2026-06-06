require "test_helper"

class TripPaymentRequestTest < ActiveSupport::TestCase
  test "validates required fields and amount" do
    payment_request = TripPaymentRequest.new

    assert_not payment_request.valid?
    assert_includes payment_request.errors[:trip], "must exist"
    assert_includes payment_request.errors[:first_name], "can't be blank"
    assert_includes payment_request.errors[:last_name], "can't be blank"
    assert_includes payment_request.errors[:email], "can't be blank"
    assert_includes payment_request.errors[:reason], "can't be blank"
    assert_includes payment_request.errors[:amount_cents], "must be greater than 0"
  end

  test "amount getter and setter convert dollars to cents" do
    payment_request = trips(:yosemite).trip_payment_requests.build(
      first_name: "Cam",
      last_name: "Stone",
      email: "cam@example.com",
      reason: "Extra permit"
    )

    payment_request.amount = "42.50"

    assert_equal 4250, payment_request.amount_cents
    assert_equal BigDecimal("42.5"), payment_request.amount
  end

  test "public signed token resolves request" do
    payment_request = trips(:yosemite).trip_payment_requests.create!(
      first_name: "Cam",
      last_name: "Stone",
      email: "cam@example.com",
      amount_cents: 4250,
      reason: "Extra permit"
    )

    assert_equal payment_request, TripPaymentRequest.find_signed(payment_request.public_token, purpose: :trip_payment_request)
  end

  test "defaults expiration to 30 days" do
    payment_request = trips(:yosemite).trip_payment_requests.create!(
      first_name: "Cam",
      last_name: "Stone",
      email: "cam@example.com",
      amount_cents: 4250,
      reason: "Extra permit"
    )

    assert_in_delta 30.days.from_now.to_i, payment_request.expires_at.to_i, 5
  end
end
