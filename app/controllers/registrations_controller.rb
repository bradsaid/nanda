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

  def send_verification_email(user)
    Timeout.timeout(5) do
      AuthMailer.verify_email(user).deliver_now
    end
  rescue => e
    Rails.logger.error "[registrations] verify email failed for #{user.email_address}: #{e.class} #{e.message}"
  end
end
