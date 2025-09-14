module Authentication
  extend ActiveSupport::Concern

  included do
    # disable any guards everywhere for now
    skip_before_action :require_login, :require_admin, :require_authentication, raise: false
    helper_method :current_user, :logged_in?
  end

  # no-ops (TEMP)
  def current_user = nil
  def logged_in?   = false
  def require_authentication; true; end
  def require_login;          true; end
  def require_admin;          true; end
  def resume_session;         true; end

  private

  def authenticated?            = true
  def find_session_by_cookie    = nil
  def request_authentication    = true
  def after_authentication_url  = (root_url rescue "/")
  def start_new_session_for(_u) = true
  def terminate_session         = true
end
