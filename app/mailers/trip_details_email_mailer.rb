class TripDetailsEmailMailer < ApplicationMailer
  def details
    @trip_details_email = params[:trip_details_email]
    recipients = params[:recipients]

    mail(
      to: recipients.map(&:email),
      subject: @trip_details_email.subject
    )
  end
end
