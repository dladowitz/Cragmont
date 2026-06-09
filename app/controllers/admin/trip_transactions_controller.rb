class Admin::TripTransactionsController < Admin::BaseController
  before_action :set_trip

  def index
    authorize @trip, :manage_payments?
    @ledger_entries = TripTransactionLedger.call(@trip)
  end

  def refund
    authorize @trip, :manage_payments?
    payment = CampsiteSignupPayment
      .joins(:campsite_signup)
      .includes(campsite_signup: :user)
      .find_by(id: params[:id], campsite_signups: { trip_id: @trip.id })

    if @trip.deleted?
      redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. Restore this trip before issuing refunds.", status: :see_other
    elsif payment.blank?
      redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. We couldn't find that transaction.", status: :see_other
    elsif !payment.stripe_source?
      redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. Only Stripe transactions can be refunded here.", status: :see_other
    elsif payment.remaining_refundable_amount_cents.zero?
      redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. There is nothing left to refund.", status: :see_other
    elsif refund_reason.blank?
      redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. Add a reason for the refund.", status: :see_other
    elsif refund_amount_cents.blank? || refund_amount_cents <= 0
      redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. Enter a refund amount greater than $0.", status: :see_other
    elsif refund_amount_cents > payment.remaining_refundable_amount_cents
      redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. The refund amount exceeds the remaining refundable amount.", status: :see_other
    else
      refund_record = StripeRefundCreator.new(
        payment: payment,
        amount_cents: refund_amount_cents,
        reason: refund_reason,
        initiated_by: "admin",
        refunded_by: current_user,
        refund_type: refund_type
      ).call

      if refund_record.succeeded?
        redirect_to admin_trip_transactions_path(@trip), notice: "On belay! #{payment.campsite_signup.user.full_name} was refunded #{helpers.format_cents(refund_record.amount_cents)}.", status: :see_other
      else
        redirect_to admin_trip_transactions_path(@trip), alert: "Wow, that was a whipper. #{refund_record.failure_reason.presence || "The refund could not be issued."}", status: :see_other
      end
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def refund_params
    params.fetch(:refund, {}).permit(:amount, :reason, :trip_expense)
  end

  def refund_reason
    refund_params[:reason].to_s.strip
  end

  def refund_amount_cents
    amount = BigDecimal(refund_params[:amount].to_s)
    cents = amount * 100
    return unless amount.positive? && cents.frac.zero?

    cents.to_i
  rescue ArgumentError
    nil
  end

  def refund_type
    ActiveModel::Type::Boolean.new.cast(refund_params[:trip_expense]) ? "trip_expense" : "admin_created"
  end
end
