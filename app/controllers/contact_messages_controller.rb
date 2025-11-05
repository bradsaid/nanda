class ContactMessagesController < ApplicationController
  # POST /contact
  def create
    # honeypot
    if params[:phone_number].present?
      redirect_back fallback_location: contact_path, alert: "Submission blocked." and return
    end

    name    = params[:name].to_s.strip
    email   = params[:email].to_s.strip
    message = params[:message].to_s.strip

    if name.blank? || email.blank? || message.blank?
      redirect_back fallback_location: contact_path, alert: "Please fill all fields." and return
    end

    begin
      ContactMailer.contact_email(name:, email:, message:).deliver_now
      redirect_back fallback_location: contact_path, notice: "Thanks—your message was sent."
    rescue => e
      Rails.logger.error "Contact mail failed: #{e.class} — #{e.message}"
      redirect_back fallback_location: contact_path, alert: "Could not send email right now. Please try again later."
    end
  end
end
