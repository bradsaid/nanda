class ApplicationMailer < ActionMailer::Base
  # MAILER_FROM must be an address the SMTP account is actually allowed to
  # send as — the authenticated Workspace user, or a verified "send mail as"
  # alias on it. Gmail silently rewrites or rejects anything else, which is
  # why the old hardcoded from@nakedandafraidfan.com never worked.
  default from: ENV.fetch("MAILER_FROM", "from@nakedandafraidfan.com")
  layout "mailer"
end
