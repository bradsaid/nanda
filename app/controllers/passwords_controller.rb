class PasswordsController < ApplicationController
  before_action :set_user_by_token, only: %i[edit update]

  def new
  end

  def create
    if user = User.find_by_email(params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    password     = params[:password].to_s
    confirmation = params[:password_confirmation].to_s

    # has_secure_password skips a blank password on update, so without this
    # check an empty form "succeeds" and leaves the old password in place.
    if password.blank?
      redirect_to edit_password_path(params[:token]), alert: "Please enter a new password."
    elsif @user.update(password: password, password_confirmation: confirmation)
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]),
                  alert: @user.errors.full_messages.to_sentence.presence || "Could not reset your password."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
