module Forum
  # Every forum controller inherits from this. Two invariants:
  #   1. If ENV["FORUM_ENABLED"] != "true", the entire forum is 404 to the
  #      public. Admins still get through so we can preview.
  #   2. Writes require a verified account. Reads are open.
  class BaseController < ApplicationController
    skip_after_action :record_page_view, raise: false

    WRITE_ACTIONS = %w[new create edit update destroy].freeze

    before_action :ensure_forum_available
    before_action :require_verified_user, if: :write_action?

    helper_method :forum_read_only?

    private

    def ensure_forum_available
      return if forum_enabled? || admin_signed_in?
      raise ActionController::RoutingError, "Not Found"
    end

    def forum_read_only? = !forum_enabled?

    def write_action?
      WRITE_ACTIONS.include?(action_name.to_s)
    end
  end
end
