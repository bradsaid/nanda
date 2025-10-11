class ContactMailer < ApplicationMailer
  default to:   "bradsaid@gmail.com",
          from: "no-reply@nakedandafraidfan.com"

  def contact_email(name:, email:, message:)
    @name, @email, @message = name, email, message
    mail(subject: "[Contact] Naked & Afraid Fan Wiki", reply_to: email)
  end
end
