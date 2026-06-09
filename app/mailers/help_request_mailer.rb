class HelpRequestMailer < ApplicationMailer
  def admin_notification
    @help_request = params[:help_request]

    mail(
      to: HelpNotificationSubscriber.pluck(:email),
      subject: "Cragmont help request: #{@help_request.reason_label}"
    )
  end

  def confirmation
    @help_request = params[:help_request]
    @request_url = help_request_url(
      @help_request,
      access: @help_request.signed_id(purpose: HelpRequest::ACCESS_TOKEN_PURPOSE)
    )

    mail(
      to: @help_request.email,
      subject: "On belay! We got your help request"
    )
  end

  def reply
    @reply = params[:reply]
    @help_request = @reply.help_request
    @reply_url = help_request_url(
      @help_request,
      access: @help_request.signed_id(purpose: HelpRequest::ACCESS_TOKEN_PURPOSE)
    )

    mail(
      to: @help_request.email,
      subject: "Cragmont help request reply: #{@help_request.subject}"
    )
  end

  def user_reply_notification
    @reply = params[:reply]
    @help_request = @reply.help_request

    mail(
      to: HelpNotificationSubscriber.pluck(:email),
      subject: "Cragmont help request updated: #{@help_request.reason_label}"
    )
  end
end
