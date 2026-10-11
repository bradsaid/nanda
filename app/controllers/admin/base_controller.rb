module Admin
  class BaseController < ApplicationController
    skip_after_action :record_page_view

    before_action :require_admin_user
    before_action :set_paper_trail_whodunnit
    helper_method :current_admin, :full_admin?, :episode_editor?

    def user_for_paper_trail
      @current_admin&.email_address
    end

    private

    # Goes through current_user like the rest of the site, so the persistent
    # remember-me cookie signs an admin in here too (it used to look only at
    # session[:user_id], which dies with the browser) and a banned account is
    # refused rather than waved through on a still-live session.
    def require_admin_user
      @current_admin = current_user
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
