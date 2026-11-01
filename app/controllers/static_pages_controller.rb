# app/controllers/static_pages_controller.rb
class StaticPagesController < ApplicationController
  def podcasts
    # No logic needed for a static page, but you could add instance variables here if it becomes dynamic later
  end

  # Bump this whenever the wording of the guidelines changes; it is shown on the
  # page and in its structured data.
  GUIDELINES_UPDATED_ON = Date.new(2026, 11, 1)

  # Public whether or not the forum is open; see the route comment.
  def guidelines
    @updated_on = GUIDELINES_UPDATED_ON
  end

  def about
    # Optional: populate @updates from DB later. For now, leave nil and the view provides fallbacks.
  end

=begin
  def contact
    if params[:phone_number].present?
      Rails.logger.warn "🚫 Spam detected, form rejected (honeypot filled)"
      redirect_to about_path, alert: "Submission blocked." and return
    end

    name    = params[:name].to_s.strip
    email   = params[:email].to_s.strip
    message = params[:message].to_s.strip

    begin
      ContactMailer.contact_email(name:, email:, message:).deliver_now
      flash[:notice] = "Thanks for your message! I’ll get back to you soon."
    rescue => e
      Rails.logger.error "Contact mail failed: #{e.class} — #{e.message}"
      flash[:alert] = "Could not send email right now. Please try again later."
    end

    redirect_to about_path
  end
=end

  
end