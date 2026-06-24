class ApplicationMailer < ActionMailer::Base
  DEFAULT_FROM = "Cragmont Climbing <notifications@cragmontclimbing.com>"

  default from: -> { ENV.fetch("MAILER_FROM", DEFAULT_FROM) }
  helper ApplicationHelper
  layout "mailer"
end
