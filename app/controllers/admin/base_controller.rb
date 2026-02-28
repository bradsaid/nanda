module Admin
  class BaseController < ApplicationController
    skip_after_action :record_page_view

    before_action :require_admin_user

    private

    def require_admin_user
      @current_admin = User.find_by(id: session[:user_id])
      unless @current_admin&.admin?
        redirect_to root_path, alert: "Not authorized."
      end
    end
  end
end
