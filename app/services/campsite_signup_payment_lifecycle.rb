class CampsiteSignupPaymentLifecycle
  DEFAULT_PENDING_EXPIRATION = 30.minutes
  ADMIN_PENDING_EXPIRATION = 30.days
  MAX_CHECKOUT_EXPIRATION = 24.hours

  def self.create_pending_checkout!(signup:, pricing:, success_url:, cancel_url:, created_by: nil, previous_signup_status: nil, expires_at: DEFAULT_PENDING_EXPIRATION.from_now)
    payment = nil
    checkout_expires_at = checkout_expires_at_for(expires_at)

    CampsiteSignup.transaction do
      signup.lock!
      payment = signup.payments.create!(
        source: "stripe",
        status: "pending",
        amount_cents: pricing.amount_cents,
        currency: pricing.currency,
        expires_at: expires_at,
        checkout_expires_at: checkout_expires_at,
        created_by: created_by,
        previous_signup_status: previous_signup_status || signup.status,
        pricing_snapshot: pricing.snapshot
      )
    end

    StripeCheckoutSessionCreator.create(
      payment: payment,
      success_url: success_url,
      cancel_url: cancel_url
    )
  rescue StripeConfigurationError, Stripe::StripeError => error
    payment&.update!(status: "failed", note: error.message)
    if signup&.pending_payment?
      signup.update!(status: "canceled")
      signup.guest_signups.pending_payment.find_each { |guest_signup| guest_signup.update!(status: "canceled") }
    end
    raise
  end

  def self.refresh_checkout!(payment:, success_url:, cancel_url:)
    payment.with_lock do
      return payment unless payment.pending?

      if payment.payment_link_expired?
        expire_checkout!(payment: payment)
        return payment
      end

      return payment if payment.checkout_active?

      payment.update!(checkout_expires_at: checkout_expires_at_for(payment.expires_at))
    end

    StripeCheckoutSessionCreator.create(
      payment: payment,
      success_url: success_url,
      cancel_url: cancel_url
    )
  rescue StripeConfigurationError, Stripe::StripeError => error
    payment.update!(status: "failed", note: error.message) if payment.pending?
    raise
  end

  def self.mark_waived!(signup:, pricing:, reason:, created_by: nil)
    signup.payments.create!(
      source: "waived",
      status: "waived",
      amount_cents: pricing.amount_cents,
      currency: pricing.currency,
      waived_reason: reason,
      created_by: created_by,
      pricing_snapshot: pricing.snapshot
    )
  end

  def self.mark_manual_paid!(signup:, pricing:, method:, paid_at:, note: nil, created_by: nil)
    signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: pricing.amount_cents,
      currency: pricing.currency,
      manual_payment_method: method,
      manual_paid_at: paid_at,
      paid_at: paid_at,
      note: note,
      created_by: created_by,
      pricing_snapshot: pricing.snapshot
    )
  end

  def self.fulfill_checkout!(payment:, stripe_payment_intent_id:)
    CampsiteSignup.transaction do
      payment.lock!
      return payment if payment.paid?

      signup = payment.campsite_signup
      signup.lock!

      payment.update!(
        status: "paid",
        stripe_payment_intent_id: stripe_payment_intent_id,
        paid_at: Time.current
      )

      if signup.pending_payment?
        signup.update!(status: "confirmed", waitlist_eligible_at: nil)
        signup.guest_signups.pending_payment.find_each do |guest_signup|
          guest_signup.update!(status: "confirmed", waitlist_eligible_at: nil)
        end
        signup.campsite.lock_signups_if_full!
      end

      payment
    end
  end

  def self.expire_checkout!(payment:, stripe_checkout_session_id: nil)
    CampsiteSignup.transaction do
      payment.lock!
      return payment unless payment.pending?
      return payment if stripe_checkout_session_id.present? && payment.stripe_checkout_session_id.present? && payment.stripe_checkout_session_id != stripe_checkout_session_id

      if payment.long_lived_payment_link? && !payment.payment_link_expired?
        payment.update!(
          checkout_url: nil,
          stripe_checkout_session_id: nil,
          checkout_expires_at: nil
        )
        return payment
      end

      signup = payment.campsite_signup
      signup.lock!
      payment.update!(status: "expired", expired_at: Time.current)

      if signup.pending_payment?
        if payment.previous_signup_status == "waitlisted"
          signup.update!(status: "waitlisted", campsite: nil, arrival_date: nil, checkout_date: nil, parking_status: "unassigned")
          signup.guest_signups.pending_payment.find_each do |guest_signup|
            guest_signup.update!(status: "waitlisted", campsite: nil, arrival_date: nil, checkout_date: nil, parking_status: "unassigned")
          end
        else
          signup.update!(status: "canceled", parking_status: "unassigned")
          signup.guest_signups.pending_payment.find_each { |guest_signup| guest_signup.update!(status: "canceled", parking_status: "unassigned") }
        end
      end

      payment
    end
  end

  def self.cancel_or_refund_signup!(signup:, reason:, issue_refund: true, refund_initiated_by: "system", refunded_by: nil)
    refund_record = refund_payment_for!(signup: signup, reason: reason, initiated_by: refund_initiated_by, refunded_by: refunded_by) if issue_refund

    CampsiteSignup.transaction do
      signup.lock!
      signup.update!(status: "canceled", parking_status: "unassigned")
      signup.guest_signups.where.not(status: "canceled").find_each { |guest_signup| guest_signup.update!(status: "canceled", parking_status: "unassigned") }
    end

    refund_record
  end

  def self.refund_payment_for!(signup:, reason:, initiated_by: "system", refunded_by: nil)
    payment = signup.primary_signup.current_payment
    amount_cents = signup.refundable_amount_cents
    return if payment.blank? || !payment.refundable? || amount_cents.zero?

    if payment.stripe_source?
      StripeRefundCreator.new(
        payment: payment,
        amount_cents: amount_cents,
        reason: reason,
        initiated_by: initiated_by,
        refunded_by: refunded_by
      ).call
    else
      payment.update!(
        refunded_amount_cents: payment.refunded_amount_cents + amount_cents
      )
      payment.complete_refund!
      nil
    end
  end

  def self.checkout_expires_at_for(expires_at)
    [ expires_at, MAX_CHECKOUT_EXPIRATION.from_now ].compact.min
  end
end
