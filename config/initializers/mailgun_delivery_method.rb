require Rails.root.join("app/mailers/mailgun_delivery_method")

if Rails.env.production?
  ActionMailer::Base.add_delivery_method :mailgun, MailgunDeliveryMethod, {
    api_key: ENV.fetch("MAILGUN_API_KEY"),
    domain: ENV.fetch("MAILGUN_DOMAIN")
  }
end
