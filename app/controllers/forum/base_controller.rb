module Forum
  # Every forum controller inherits from this. Two invariants:
  #   1. If ENV["FORUM_ENABLED"] != "true", the entire forum is 404 to the
  #      public. Admins still get through so we can preview.
  #   2. Writes require a verified account. Reads are open.
  class BaseController < ApplicationController
    WRITE_ACTIONS = %w[new create edit update destroy].freeze

    before_action :ensure_forum_available
    before_action :require_verified_user, if: :write_action?

    helper_method :forum_read_only?

    private

    def ensure_forum_available
      return if forum_enabled? || forum_preview_access?
      raise ActionController::RoutingError, "Not Found"
    end

    def forum_read_only? = !forum_enabled?

    def write_action?
      WRITE_ACTIONS.include?(action_name.to_s)
    end

    # Content type on an upload comes from the browser, which derives it from
    # the filename — so a text file renamed .jpg arrives declared as
    # image/jpeg and sails past a content-type allowlist. Sniff the actual
    # leading bytes instead. Returns the offending filename, or nil if fine.
    def first_disguised_upload(uploads)
      Array(uploads).reject(&:blank?).each do |up|
        next unless up.respond_to?(:tempfile)
        head = up.tempfile.read(4096).to_s
        up.tempfile.rewind
        sniffed = Marcel::MimeType.for(StringIO.new(head))
        return up.original_filename unless Forum::Post::ALLOWED_IMAGE_TYPES.include?(sniffed)
      end
      nil
    end
  end
end
