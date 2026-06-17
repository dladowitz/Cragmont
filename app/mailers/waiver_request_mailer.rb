class WaiverRequestMailer < ApplicationMailer
  def sign_request
    @user = params[:user]
    @requested_by = params[:requested_by]
    @waiver_url = params[:waiver_url]

    mail(
      to: @user.email,
      subject: "Cragmont Waiver Signing Request"
    )
  end
end
