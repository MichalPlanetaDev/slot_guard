class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch(
    "MAIL_FROM",
    "SlotGuard <no-reply@slotguard.test>"
  )

  layout "mailer"
end
