class Admin::TripPaymentRequestsController < Admin::BaseController
  before_action :set_trip
  before_action :ensure_trip_not_deleted
  before_action :set_payment_request, only: %i[email cancel]

  def create
    authorize @trip, :manage_payments?
    @payment_request = @trip.trip_payment_requests.build(payment_request_params.merge(created_by: current_user))

    if @payment_request.save
      create_checkout_session!
      redirect_to admin_trip_path(@trip, payment_request: @payment_request.admin_modal_token, anchor: "trip-payment-requests"),
        notice: "On belay! Payment request was created."
    else
      redirect_to admin_trip_path(@trip, anchor: "trip-payment-requests"),
        alert: "Wow, that was a whipper. #{@payment_request.errors.full_messages.to_sentence}",
        status: :see_other
    end
  rescue StripeConfigurationError => error
    @payment_request&.destroy if @payment_request&.persisted? && @payment_request.pending?
    redirect_to admin_trip_path(@trip, anchor: "trip-payment-requests"),
      alert: "Wow, that was a whipper. #{error.message}",
      status: :see_other
  end

  def email
    authorize @trip, :manage_payments?

    if @payment_request.pending?
      TripPaymentRequestMailer.with(
        payment_request: @payment_request,
        payment_url: trip_payment_request_url(@payment_request.public_token)
      ).request_payment.deliver_now
      message = "On belay! The payment link was emailed to #{@payment_request.full_name}."
      respond_to do |format|
        format.html { redirect_to admin_trip_path(@trip, anchor: "trip-payment-requests"), notice: message }
        format.json { render json: { message: message, button_text: "Email sent" } }
      end
    else
      respond_with_failure("This payment request is already #{@payment_request.status}.")
    end
  end

  def cancel
    authorize @trip, :manage_payments?

    if @payment_request.pending?
      TripPaymentRequestCheckoutSessionExpirer.expire(payment_request: @payment_request)
      @payment_request.cancel!(canceled_by: current_user)
      redirect_to admin_trip_path(@trip, anchor: "trip-payment-requests"),
        notice: "Off belay. Payment request was canceled.",
        status: :see_other
    else
      redirect_to admin_trip_path(@trip, anchor: "trip-payment-requests"),
        alert: "That payment request is already #{@payment_request.status}.",
        status: :see_other
    end
  rescue StripeConfigurationError => error
    redirect_to admin_trip_path(@trip, anchor: "trip-payment-requests"),
      alert: "Wow, that was a whipper. #{error.message}",
      status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def ensure_trip_not_deleted
    return unless @trip.deleted?

    redirect_to admin_trip_path(@trip), alert: "Restore this trip before making changes.", status: :see_other
  end

  def set_payment_request
    @payment_request = @trip.trip_payment_requests.find(params[:id])
  end

  def payment_request_params
    params.require(:trip_payment_request).permit(:first_name, :last_name, :email, :amount, :reason)
  end

  def create_checkout_session!
    payment_request_url = trip_payment_request_url(@payment_request.public_token)
    TripPaymentRequestCheckoutSessionCreator.create(
      payment_request: @payment_request,
      success_url: "#{payment_request_url}?stripe_checkout=success",
      cancel_url: "#{payment_request_url}?stripe_checkout=canceled"
    )
  end

  def respond_with_failure(message)
    respond_to do |format|
      format.html { redirect_to admin_trip_path(@trip, anchor: "trip-payment-requests"), alert: message }
      format.json { render json: { message: message, button_text: "Email failed" }, status: :unprocessable_entity }
    end
  end
end
