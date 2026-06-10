class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Cragmont Climbing <postmaster@#{ENV.fetch('MAILGUN_DOMAIN', 'cragmontclimbing.com')}>")
  layout "mailer"
end
