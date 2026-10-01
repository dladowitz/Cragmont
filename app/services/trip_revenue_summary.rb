class TripRevenueSummary
  CampsiteLine = Struct.new(:campsite, :paid_cents, :refund_cents, :net_cents, keyword_init: true) do
    def label
      "#{campsite.campground.name} site #{campsite.site_number}"
    end
  end
  RegistrationFeeLine = Struct.new(:campsite, :fee_cents, keyword_init: true) do
    def campsite_label
      "#{campsite.campground.name} site #{campsite.site_number}"
    end

    def label
      "#{campsite_label} registration fee"
    end
  end
  TripExpenseLine = Struct.new(:refund, keyword_init: true) do
    def payment
      refund.campsite_signup_payment
    end

    def participant_name
      payment.campsite_signup.user.full_name
    end

    def reason
      refund.reason.presence || "None"
    end

    def amount_cents
      refund.amount_cents
    end

    def transaction_anchor
      "transaction-payment-#{payment.id}"
    end
  end
  StripeProcessingFeeLine = Struct.new(:payment, keyword_init: true) do
    def participant_name
      payment.campsite_signup.user.full_name
    end

    def amount_cents
      payment.amount_cents
    end

    def fee_cents
      payment.stripe_processing_fee_cents.to_i
    end

    def net_cents
      amount_cents - fee_cents
    end
  end

  attr_reader :trip

  def self.call(trip)
    new(trip).call
  end

  def initialize(trip)
    @trip = trip
  end

  def call
    self
  end

  def campsite_lines
    @campsite_lines ||= trip.campsites.includes(:campground).order(:arrival_date, :site_number).map do |campsite|
      paid_cents = campsite_paid_cents.fetch(campsite.id, 0)
      refund_cents = campsite_participant_refund_cents.fetch(campsite.id, 0)

      CampsiteLine.new(
        campsite: campsite,
        paid_cents: paid_cents,
        refund_cents: refund_cents,
        net_cents: paid_cents - refund_cents
      )
    end
  end

  def campsite_revenue_cents
    campsite_lines.sum(&:net_cents)
  end

  def campsite_registration_fee_lines
    @campsite_registration_fee_lines ||= trip.campsites.includes(:campground).order(:arrival_date, :site_number).map do |campsite|
      RegistrationFeeLine.new(campsite: campsite, fee_cents: campsite.registration_fee_cents)
    end
  end

  def one_time_payment_requests_cents
    @one_time_payment_requests_cents ||= trip.trip_payment_requests.paid.sum(:amount_cents)
  end

  def total_revenue_cents
    campsite_revenue_cents + one_time_payment_requests_cents - stripe_processing_fee_cents
  end

  def trip_expense_refund_cents
    trip_expense_lines.sum(&:amount_cents)
  end

  def trip_expense_lines
    @trip_expense_lines ||= CampsiteSignupPaymentRefund.trip_expense_refund_type
      .succeeded
      .joins(campsite_signup_payment: :campsite_signup)
      .where(campsite_signups: { trip_id: trip.id })
      .includes(campsite_signup_payment: { campsite_signup: :user })
      .order(refunded_at: :desc, created_at: :desc)
      .map { |refund| TripExpenseLine.new(refund: refund) }
  end

  def campsite_registration_fee_cents
    campsite_registration_fee_lines.sum(&:fee_cents)
  end

  def stripe_processing_fee_cents
    @stripe_processing_fee_cents ||= stripe_processing_fee_lines.sum(&:fee_cents)
  end

  def stripe_processing_fee_lines
    @stripe_processing_fee_lines ||= CampsiteSignupPayment
      .joins(:campsite_signup)
      .where(campsite_signups: { trip_id: trip.id })
      .where(source: "stripe", status: %w[paid refunded partially_refunded])
      .where.not(stripe_processing_fee_cents: nil)
      .includes(campsite_signup: :user)
      .order(:paid_at, :created_at, :id)
      .map { |payment| StripeProcessingFeeLine.new(payment: payment) }
  end

  def total_expense_cents
    trip_expense_refund_cents + campsite_registration_fee_cents
  end

  def final_total_cents
    total_revenue_cents - total_expense_cents
  end

  private

  def campsite_paid_cents
    @campsite_paid_cents ||= CampsiteSignupPayment
      .joins(campsite_signup: :campsite)
      .where(campsite_signups: { trip_id: trip.id })
      .where(status: %w[paid refunded partially_refunded])
      .group("campsites.id")
      .sum(:amount_cents)
  end

  def campsite_participant_refund_cents
    @campsite_participant_refund_cents ||= CampsiteSignupPaymentRefund
      .succeeded
      .where.not(refund_type: "trip_expense")
      .joins(campsite_signup_payment: { campsite_signup: :campsite })
      .where(campsite_signups: { trip_id: trip.id })
      .group("campsites.id")
      .sum(:amount_cents)
  end
end
