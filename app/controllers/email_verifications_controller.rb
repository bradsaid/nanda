class EmailVerificationsController < ApplicationController
  def show
    user = User.find_by_token_for(:email_verification, params[:token])
    if user.nil?
      redirect_to root_path, alert: "That verification link is invalid or expired."
      return
    end

    if user.email_verified?
      redirect_to new_session_path, notice: "Your email is already verified. Please sign in."
      return
    end

    user.update!(email_verified_at: Time.current)
    redirect_to new_session_path, notice: "Email verified. You can now sign in."
  end

  def resend
    email = params[:email_address].to_s.strip.downcase
    user = User.find_by(email_address: email)
    if user && !user.email_verified?
      Timeout.timeout(5) do
        AuthMailer.verify_email(user).deliver_now
      end
    end
    redirect_to root_path, notice: "If that account exists and needs verification, a new email is on the way."
  rescue => e
    Rails.logger.error "[email_verifications#resend] #{e.class} #{e.message}"
    redirect_to root_path, notice: "If that account exists and needs verification, a new email is on the way."
  end
end
