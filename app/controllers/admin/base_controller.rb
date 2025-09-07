class Admin::BaseController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    resume_session
    redirect_to new_session_path, alert: "Admin access required" unless Current.user&.admin?
  end
end
