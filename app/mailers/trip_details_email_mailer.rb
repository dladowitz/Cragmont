class TripDetailsEmailMailer < ApplicationMailer
  def details
    @trip_details_email = params[:trip_details_email]
    @recipient = params[:recipient]

    mail(
      to: @recipient.email,
      subject: @trip_details_email.subject
    )
  end
end
