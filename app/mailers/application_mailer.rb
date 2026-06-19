class ApplicationMailer < ActionMailer::Base
  DEFAULT_FROM = "Cragmont Climbing <postmaster@cragmontclimbing.com>"

  default from: -> { ENV.fetch("MAILER_FROM", DEFAULT_FROM) }
  layout "mailer"
end
