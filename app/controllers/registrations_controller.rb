class RegistrationsController < ApplicationController
  # Kill switch: setting SIGNUPS_DISABLED=1 in the environment blocks all
  # new registrations without a deploy. Used if the signup endpoint gets
  # hit by a bot avalanche.
  before_action :redirect_if_signed_in, only: %i[new create]
  before_action :block_if_signups_disabled, only: :create
  before_action :reject_honeypot, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.role = :user
    if @user.save
      send_verification_email(@user)
      notify_owner_of_signup(@user)
      redirect_to new_session_path,
        notice: "Account created. Check your email for a verification link (valid for 48 hours)."
    else
      flash.now[:alert] = "Please correct the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :username, :password, :password_confirmation)
  end

  def redirect_if_signed_in
    redirect_to root_path, notice: "You are already signed in." if logged_in?
  end

  def block_if_signups_disabled
    return unless ENV["SIGNUPS_DISABLED"] == "1"
    redirect_to root_path, alert: "Signups are temporarily paused."
  end

  # Simple honeypot: bots fill in every visible field including hidden ones.
  # We render a `phone_number` field with CSS `display:none` on the form;
  # any submission that populates it is a bot.
  def reject_honeypot
    return if params.dig(:user, :phone_number).blank?
    Rails.logger.info "[registrations] honeypot triggered from #{request.remote_ip}"
    redirect_to root_path, notice: "Thanks!"
  end

  # Queued, not sent inline. Previously this was deliver_now wrapped in a 5s
  # timeout that swallowed failures, so a slow or misconfigured SMTP server
  # made signup feel broken — or silently dropped the verification link while
  # still reporting success. Solid Queue now owns delivery and retries.
  # Queued like the verification email. A failure here must never affect the
  # person registering — they have done nothing wrong and their account is
  # already saved.
  def notify_owner_of_signup(user)
    AuthMailer.new_signup(user).deliver_later
  rescue => e
    Rails.logger.error "[registrations] could not enqueue signup notice for #{user.email_address}: #{e.class} #{e.message}"
  end

  def send_verification_email(user)
    AuthMailer.verify_email(user).deliver_later
  rescue => e
    Rails.logger.error "[registrations] could not enqueue verify email for #{user.email_address}: #{e.class} #{e.message}"
  end
end
