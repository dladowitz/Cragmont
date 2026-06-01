class PasswordResetMailer < ApplicationMailer
  def reset
    @user = params[:user]
    @token = params[:token]
    @reset_url = edit_password_reset_url(@token, reset_url_options)

    mail(to: @user.email, subject: "Reset your Cragmont password")
  end

  private

  def reset_url_options
    options = {}
    options[:host] = params[:request_host] if params[:request_host].present?
    options[:protocol] = params[:request_protocol] if params[:request_protocol].present?
    options
  end
end
