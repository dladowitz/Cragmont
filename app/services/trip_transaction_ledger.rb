class TripTransactionLedger
  Entry = Struct.new(:payment, keyword_init: true) do
    def participant_name
      payment.campsite_signup.user.full_name
    end

    def campsite_id
      payment.campsite_signup.campsite_id
    end

    def refunded?
      payment.refunded_amount_cents.positive? || payment.refunded? || payment.partially_refunded?
    end

    def status_label
      if payment.remaining_refundable_amount_cents.zero? && payment.refunded_amount_cents.positive?
        "Refunded"
      elsif payment.refunded_amount_cents.positive? && payment.remaining_refundable_amount_cents.positive?
        "Partially Refunded"
      elsif payment.pending?
        "Pending"
      else
        "Paid"
      end
    end

    def status_class
      if status_label == "Refunded"
        "danger-status"
      elsif status_label == "Partially Refunded"
        "warning-status"
      elsif payment.pending?
        "warning-status"
      end
    end

    def amount_cents
      payment.amount_cents
    end

    def occurred_at
      payment.paid_at || payment.manual_paid_at || payment.created_at
    end

    def refunds
      payment.refunds.order(refunded_at: :desc, updated_at: :desc)
    end

    def source
      payment.source
    end

    def status
      payment.status
    end
  end

  def self.call(trip)
    new(trip).entries
  end

  def self.for_user(user)
    new(nil, user: user).entries
  end

  def initialize(trip, user: nil)
    @trip = trip
    @user = user
  end

  def entries
    payment_entries.sort_by { |entry| [ entry.occurred_at || Time.zone.at(0), entry.amount_cents ] }.reverse
  end

  private

  attr_reader :trip, :user

  def payment_entries
    payments.map { |payment| Entry.new(payment: payment) }
  end

  def payments
    scope = CampsiteSignupPayment.completed_for_transactions
      .joins(:campsite_signup)
      .includes(:created_by, refunds: :refunded_by, campsite_signup: [ :user, :campsite ])

    scope = scope.where(campsite_signups: { trip_id: trip.id }) if trip.present?
    scope = scope.where(campsite_signups: { user_id: user.id }) if user.present?
    scope
  end
end
