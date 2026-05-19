module Admin
  class BaseController < ApplicationController
    skip_after_action :record_page_view

    before_action :require_admin_user
    helper_method :current_admin, :full_admin?, :episode_editor?

    private

    def require_admin_user
      @current_admin = User.find_by(id: session[:user_id])
      unless @current_admin && (@current_admin.admin? || @current_admin.episode_editor?)
        redirect_to root_path, alert: "Not authorized."
      end
    end

    def require_full_admin!
      unless full_admin?
        redirect_to admin_episodes_path, alert: "Not authorized for that action."
      end
    end

    def current_admin
      @current_admin
    end

    def full_admin?
      @current_admin&.admin?
    end

    def episode_editor?
      @current_admin&.episode_editor?
    end
  end
end
