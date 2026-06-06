class GuestWaiverMailer < ApplicationMailer
  def needed
    @signup = params[:signup]
    @trip = @signup.trip
    @added_by = params[:added_by] || params[:primary_participant]
    @waiver_instruction = params[:waiver_instruction] || "Before tying in you'll need to sign the waiver."
    @waiver_url = params[:waiver_url]
    @password_reset_url = new_password_reset_url

    mail(
      to: @signup.user.email,
      subject: "Cragmont Climning #{@trip.name} #{@trip.start_date.to_fs(:long)} Waiver Needed"
    )
  end
end
