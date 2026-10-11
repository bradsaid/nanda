class SurvivorSubmissionsController < ApplicationController
  MAX_MESSAGE = 5_000
  # The photo is attached to an email addressed to Brad, so only real images
  # are accepted - not an arbitrary file under any extension.
  PHOTO_TYPES = %w[image/jpeg image/png image/gif image/webp image/heic].freeze

  # POST /survivors/:slug/submit
  def create
    survivor = Survivor.friendly.find(params[:survivor_slug] || params[:slug] || params[:id])

    # Honeypot
    if params[:phone_number].present?
      redirect_to survivor_path(survivor), alert: "Submission blocked." and return
    end

    name    = params[:name].to_s.strip
    email   = params[:email].to_s.strip
    message = params[:message].to_s.strip
    photo   = params[:photo]

    if name.blank? || email.blank? || message.blank?
      redirect_to survivor_path(survivor), alert: "Please fill in your name, email, and a message." and return
    end

    # Cap photo size (~10 MB) to prevent huge attachments
    if photo.present? && photo.size > 10.megabytes
      redirect_to survivor_path(survivor), alert: "Photo is too large — please keep it under 10 MB." and return
    end

    if photo.present? && !PHOTO_TYPES.include?(photo.content_type.to_s)
      redirect_to survivor_path(survivor), alert: "Please attach a JPEG, PNG, GIF or WebP photo." and return
    end

    if name.length > 200 || email.length > 320 || message.length > MAX_MESSAGE
      redirect_to survivor_path(survivor), alert: "That message is too long." and return
    end

    begin
      ContactMailer.survivor_submission(
        survivor: survivor, name: name, email: email, message: message, photo: photo
      ).deliver_now
      redirect_to survivor_path(survivor), notice: "Thanks! Your submission was sent to Brad."
    rescue => e
      Rails.logger.error "Survivor submission failed: #{e.class} — #{e.message}"
      redirect_to survivor_path(survivor), alert: "Could not send your submission right now. Please try again later."
    end
  end
end
