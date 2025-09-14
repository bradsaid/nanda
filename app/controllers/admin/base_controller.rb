class Admin::BaseController < ApplicationController
  # TEMP: disable auth entirely
  skip_before_action :require_admin, raise: false

  private

  def require_admin
    resume_session
    return if Current.user&.admin?

    session[:return_to] = request.fullpath
    redirect_to new_session_path(return_to: request.fullpath), alert: "Admin access required"
  end
end
