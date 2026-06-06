class TripPaymentRequestMailer < ApplicationMailer
  helper ApplicationHelper

  def request_payment
    @payment_request = params[:payment_request]
    @trip = @payment_request.trip
    @payment_url = params[:payment_url]

    mail(
      to: @payment_request.email,
      subject: "Cragmont #{@trip.name} Payment Request"
    )
  end
end
