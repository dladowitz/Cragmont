require "test_helper"

class Admin::TripPaymentRequestsControllerTest < ActionDispatch::IntegrationTest
  FakeTripPaymentRequestCheckoutSessionCreator = Struct.new(:payment_request, :success_url, :cancel_url, keyword_init: true) do
    def call
      payment_request.update!(
        stripe_checkout_session_id: "cs_trip_request_#{payment_request.id}",
        checkout_url: "https://checkout.stripe.com/c/pay/trip-request-#{payment_request.id}",
        checkout_expires_at: 24.hours.from_now
      )
      payment_request
    end
  end

  FakeTripPaymentRequestCheckoutSessionExpirer = Struct.new(:payment_request, keyword_init: true) do
    def call
      payment_request.update!(checkout_url: nil, checkout_expires_at: nil)
      payment_request
    end
  end

  setup do
    log_in_as(users(:alex))
  end

  test "admin can create request and sees copy email modal" do
    with_fake_trip_payment_request_checkout do
      assert_difference "TripPaymentRequest.count", 1 do
        post admin_trip_trip_payment_requests_url(trips(:yosemite)), params: {
          trip_payment_request: {
            first_name: "Cam",
            last_name: "Stone",
            email: "cam@example.com",
            amount: "42.50",
            reason: "Extra permit"
          }
        }
      end
    end

    payment_request = TripPaymentRequest.order(:created_at).last
    assert_redirected_to admin_trip_url(trips(:yosemite), payment_request: payment_request.admin_modal_token, anchor: "trip-payment-requests")
    assert_equal "pending", payment_request.status
    assert_equal 4250, payment_request.amount_cents
    assert_equal "cs_trip_request_#{payment_request.id}", payment_request.stripe_checkout_session_id
    assert_in_delta 30.days.from_now.to_i, payment_request.expires_at.to_i, 5

    follow_redirect!
    payment_url = trip_payment_request_url(payment_request.public_token)
    assert_select "dialog.trip-payment-request-link-modal h2", text: "Payment Request Link"
    assert_select "[data-controller='copy-link'][data-copy-link-url-value='#{payment_url}']"
    assert_select "form[action=?][method='post'][data-controller='email-link'][data-action='submit->email-link#send'] button", email_admin_trip_trip_payment_request_path(trips(:yosemite), payment_request), text: "Email link to participant"
  end

  test "pending requests show on admin trip page" do
    payment_request = create_payment_request!

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#trip-payment-requests" do
      assert_select "td", text: /Cam Stone/
      assert_select "td", text: "$42.50"
      assert_select "td", text: "Extra permit"
      assert_select ".status", text: "Pending"
      assert_select "button", text: "Copy Link"
      assert_select "form[action=?][method='post']", email_admin_trip_trip_payment_request_path(trips(:yosemite), payment_request)
      assert_select "form[action=?][method='post']", cancel_admin_trip_trip_payment_request_path(trips(:yosemite), payment_request)
    end
  end

  test "email action sends link and supports json response" do
    payment_request = create_payment_request!

    assert_emails 1 do
      post email_admin_trip_trip_payment_request_url(trips(:yosemite), payment_request), as: :json
    end

    assert_response :success
    assert_equal "Email sent", JSON.parse(response.body).fetch("button_text")
  end

  test "cancel action marks request canceled" do
    payment_request = create_payment_request!(stripe_checkout_session_id: "cs_to_expire", checkout_url: "https://checkout.stripe.com/c/pay/to-expire", checkout_expires_at: 1.hour.from_now)

    with_fake_trip_payment_request_expirer do
      patch cancel_admin_trip_trip_payment_request_url(trips(:yosemite), payment_request)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite), anchor: "trip-payment-requests")
    payment_request.reload
    assert_equal "canceled", payment_request.status
    assert_equal users(:alex), payment_request.canceled_by
    assert_not_nil payment_request.canceled_at
  end

  test "deleted trips block creation and cancel" do
    trip = trips(:jtree)
    trip.soft_delete!
    payment_request = create_payment_request!(trip: trip)

    assert_no_difference "TripPaymentRequest.count" do
      post admin_trip_trip_payment_requests_url(trip), params: {
        trip_payment_request: {
          first_name: "Dana",
          last_name: "Pitch",
          email: "dana@example.com",
          amount: "10",
          reason: "Parking"
        }
      }
    end

    assert_redirected_to admin_trip_url(trip)

    patch cancel_admin_trip_trip_payment_request_url(trip, payment_request)
    assert_redirected_to admin_trip_url(trip)
    assert_equal "pending", payment_request.reload.status
  end

  private

  def create_payment_request!(trip: trips(:yosemite), **attributes)
    trip.trip_payment_requests.create!(
      {
        first_name: "Cam",
        last_name: "Stone",
        email: "cam@example.com",
        amount_cents: 4250,
        reason: "Extra permit"
      }.merge(attributes)
    )
  end

  def with_fake_trip_payment_request_checkout
    original_creator = Rails.application.config.x.trip_payment_request_checkout_session_creator
    Rails.application.config.x.trip_payment_request_checkout_session_creator = FakeTripPaymentRequestCheckoutSessionCreator
    yield
  ensure
    Rails.application.config.x.trip_payment_request_checkout_session_creator = original_creator
  end

  def with_fake_trip_payment_request_expirer
    original_expirer = Rails.application.config.x.trip_payment_request_checkout_session_expirer
    Rails.application.config.x.trip_payment_request_checkout_session_expirer = FakeTripPaymentRequestCheckoutSessionExpirer
    yield
  ensure
    Rails.application.config.x.trip_payment_request_checkout_session_expirer = original_expirer
  end
end
