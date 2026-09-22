class ContactMailer < ApplicationMailer
  # No explicit from: — ApplicationMailer's MAILER_FROM is the address the
  # Workspace account is allowed to send as. The old no-reply@ here does not
  # exist in Workspace, so Gmail would have rewritten or refused it.
  default to: ENV.fetch("CONTACT_EMAIL", "brad@nakedandafraidfan.com")

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
