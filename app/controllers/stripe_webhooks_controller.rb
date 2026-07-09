class StripeWebhooksController < ApplicationController
  skip_forgery_protection

  def create
    event = stripe_event

    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "checkout.session.expired"
      handle_checkout_expired(event.data.object)
    when "refund.updated"
      handle_refund_updated(event.data.object)
    end

    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def stripe_event
    payload = request.body.read
    signature = request.headers["Stripe-Signature"]
    webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].presence

    if webhook_secret.present?
      Stripe::Webhook.construct_event(payload, signature, webhook_secret)
    else
      Stripe::Event.construct_from(JSON.parse(payload))
    end
  end

  def handle_checkout_completed(session)
    payment_request = trip_payment_request_for_session(session)
    if payment_request.present?
      payment_request.mark_paid!(
        stripe_checkout_session_id: session.id,
        stripe_payment_intent_id: session.payment_intent
      )
      return
    end

    payment = payment_for_session(session)
    return if payment.blank?

    payment.update!(stripe_checkout_session_id: session.id)
    CampsiteSignupPaymentLifecycle.fulfill_checkout!(
      payment: payment,
      stripe_payment_intent_id: session.payment_intent
    )
    StripeProcessingFeeSyncJob.perform_later(payment.id)
  end

  def handle_checkout_expired(session)
    payment_request = trip_payment_request_for_session(session)
    if payment_request.present?
      payment_request.clear_expired_checkout!(stripe_checkout_session_id: session.id)
      return
    end

    payment = payment_for_session(session)
    return if payment.blank?

    CampsiteSignupPaymentLifecycle.expire_checkout!(payment: payment, stripe_checkout_session_id: session.id)
  end

  def handle_refund_updated(refund)
    refund_record = CampsiteSignupPaymentRefund.find_by(stripe_refund_id: refund.id)
    return if refund_record.blank?

    refund_record.update!(
      stripe_status: refund.status,
      status: refund.status == "failed" ? "failed" : refund_record.status,
      failure_reason: refund.failure_reason.presence || refund_record.failure_reason
    )
  end

  def payment_for_session(session)
    payment_id = metadata_value(session, "campsite_signup_payment_id")
    CampsiteSignupPayment.find_by(id: payment_id) || CampsiteSignupPayment.find_by(stripe_checkout_session_id: session.id)
  end

  def trip_payment_request_for_session(session)
    payment_request_id = metadata_value(session, "trip_payment_request_id")
    TripPaymentRequest.find_by(id: payment_request_id) || TripPaymentRequest.find_by(stripe_checkout_session_id: session.id)
  end

  def metadata_value(session, key)
    session.metadata&.[](key)
  end
end
