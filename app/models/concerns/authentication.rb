module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user
    helper_method :current_user, :logged_in?
  end

  def set_current_user
    Current.user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def resume_session
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def current_user = Current.user
  def logged_in?   = Current.user.present?

  # Use this in admin/writes
  def require_login
    unless logged_in?
      session[:return_to] = request.fullpath
      redirect_to new_session_path(return_to: request.fullpath), alert: "Please sign in."
    end
  end
end
