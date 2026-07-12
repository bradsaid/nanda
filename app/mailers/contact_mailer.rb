class ContactMailer < ApplicationMailer
  default to:   "bradsaid@gmail.com",
          from: "no-reply@nakedandafraidfan.com"

  def contact_email(name:, email:, message:)
    @name, @email, @message = name, email, message
    mail(subject: "[Contact] Naked & Afraid Fan Wiki", reply_to: email)
  end

  def survivor_submission(survivor:, name:, email:, message:, photo: nil)
    @survivor, @name, @email, @message = survivor, name, email, message
    @survivor_url = "https://www.nakedandafraidfan.com/survivors/#{survivor.slug}"
    if photo.present?
      attachments[photo.original_filename] = photo.read
    end
    mail(subject: "[Bio submission] #{survivor.full_name}", reply_to: email)
  end
end
