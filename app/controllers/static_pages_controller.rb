# app/controllers/static_pages_controller.rb
class StaticPagesController < ApplicationController
  def podcasts
    # No logic needed for a static page, but you could add instance variables here if it becomes dynamic later
  end

  def about
    # Optional: populate @updates from DB later. For now, leave nil and the view provides fallbacks.
  end

  def contact
    if params[:phone_number].present?
      Rails.logger.warn "🚫 Spam detected, form rejected (honeypot filled)"
      redirect_to about_path, alert: "Submission blocked." and return
    end

    name    = params[:name].to_s.strip
    email   = params[:email].to_s.strip
    message = params[:message].to_s.strip

    begin
      ContactMailer.contact_email(name:, email:, message:).deliver_later
      flash[:notice] = "Thanks for your message! I’ll get back to you soon."
    rescue => e
      Rails.logger.error "Contact mail failed: #{e.class} — #{e.message}"
      flash[:alert] = "Could not send email right now. Please try again later."
    end

    redirect_to about_path
  end


  
end