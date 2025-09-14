class ApplicationController < ActionController::Base
  # TEMP: no auth anywhere
  # remove any: before_action :require_* guards
  include Authentication
  allow_browser versions: :modern

  # If other code calls these, make them safe no-ops:
  helper_method :current_user, :logged_in?
  def current_user = nil
  def logged_in?   = false

  def require_login;  true; end
  def require_admin;  true; end
  def require_authentication; true; end
  def resume_session; true; end
end
