require "net/http"

class MailgunDeliveryMethod
  def initialize(settings)
    @api_key = settings.fetch(:api_key)
    @domain = settings.fetch(:domain)
  end

  def deliver!(mail)
    response = Net::HTTP.post_form(api_uri, mailgun_params(mail))

    return if response.is_a?(Net::HTTPSuccess)

    raise "Mailgun delivery failed: #{response.code} #{response.body}"
  end

  private

  attr_reader :api_key, :domain

  def api_uri
    URI("https://api:#{api_key}@api.mailgun.net/v3/#{domain}/messages")
  end

  def mailgun_params(mail)
    {
      from: mail[:from].to_s,
      to: Array(mail.to).join(","),
      cc: Array(mail.cc).join(","),
      bcc: Array(mail.bcc).join(","),
      subject: mail.subject.to_s,
      text: text_body(mail),
      html: html_body(mail)
    }.compact_blank
  end

  def text_body(mail)
    return mail.text_part.decoded if mail.text_part
    return mail.decoded if mail.mime_type == "text/plain"
    return if mail.html_part || mail.mime_type == "text/html"

    mail.body.decoded
  end

  def html_body(mail)
    mail.html_part&.decoded || (mail.mime_type == "text/html" ? mail.decoded : nil)
  end
end
