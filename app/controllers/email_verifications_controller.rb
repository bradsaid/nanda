class EmailVerificationsController < ApplicationController
  # GET only shows a button. Verifying is a POST so a mail scanner or link
  # preview that merely fetches the URL cannot verify an address by itself.
  def show
    @token = params[:token]
    return unless (user = verifiable_user)
    @email = user.email_address
  end

  def update
    return unless (user = verifiable_user)

    user.update!(email_verified_at: Time.current)
    redirect_to new_session_path, notice: "Email verified. You can now sign in."
  end

  def resend
    # A signed-in member is resending to themselves, so there is no address to
    # type and no enumeration question. Anyone else has to name one, and gets
    # the same answer either way.
    user = logged_in? ? current_user : User.find_by_email(params[:email_address])

    AuthMailer.verify_email(user).deliver_later if user && !user.email_verified?

    redirect_back fallback_location: root_path, notice: resend_notice
  rescue => e
    Rails.logger.error "[email_verifications#resend] #{e.class} #{e.message}"
    redirect_back fallback_location: root_path, notice: resend_notice
  end

  private

  # Returns the user for a valid, still-unverified token. Otherwise redirects
  # and returns nil, so callers can `return unless`.
  def verifiable_user
    user = User.find_by_token_for(:email_verification, params[:token])
    if user.nil?
      redirect_to root_path, alert: "That verification link is invalid or expired."
      return nil
    end
    if user.email_verified?
      redirect_to new_session_path, notice: "Your email is already verified. Please sign in."
      return nil
    end
    user
  end

  def resend_notice
    if logged_in?
      "Verification email sent to #{current_user.email_address}. It can take a minute, and it may land in your spam folder."
    else
      "If that account exists and needs verification, a new email is on the way."
    end
  end
end
