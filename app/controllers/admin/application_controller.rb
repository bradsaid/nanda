module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate

    private
    def authenticate
      authenticate_or_request_with_http_basic("Admin") do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u, ENV.fetch("ADMIN_USER")) &
        ActiveSupport::SecurityUtils.secure_compare(p, ENV.fetch("ADMIN_PASS"))
      end
    end
  end
end
