class SessionsController < ApplicationController

  def new
    @return_to = params[:return_to].presence || stored_return_to
  end

  def create
    user = User.find_by(email_address: params[:email_address])
    if user&.authenticate(params[:password])
      if user.banned?
        redirect_to new_session_path, alert: "Your account has been suspended."
        return
      end

      reset_session
      session[:user_id] = user.id
      Current.user = user

      Session.transaction do
        record = user.sessions.create!(
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        cookies.signed[:forum_session_id] = {
          value:    record.token,
          httponly: true,
          secure:   Rails.env.production?,
          same_site: :lax,
          expires:  30.days.from_now
        }
      end

      redirect_to(after_login_path(user), notice: "Signed in")
    else
      redirect_to new_session_path(return_to: params[:return_to]), alert: "Invalid email or password"
    end
  end

  def destroy
    if (token = cookies.signed[:forum_session_id]).present?
      Session.where(token: token).delete_all
    end
    cookies.delete(:forum_session_id)
    reset_session
    Current.user = nil
    redirect_to root_path, notice: "Signed out"
  end

  private

  # Admins land in the admin dashboard. Regular forum users land on
  # wherever they were trying to go (stored_return_to), or the forum index
  # if that's not set.
  def after_login_path(user)
    params[:return_to].presence ||
      stored_return_to ||
      (user.admin? || user.episode_editor? ? admin_root_path : root_path)
  end

  def stored_return_to
    session.delete(:return_to)
  end
end
