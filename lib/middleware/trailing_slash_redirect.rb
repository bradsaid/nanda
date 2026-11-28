# Permanently redirects GET/HEAD requests for "/path/" to "/path", keeping the query
# string. Rails ignores a trailing slash when routing, so /forum/, /survivors/ and every
# other page used to answer 200 as a second URL for the same content.
#
# Loaded explicitly from config/application.rb (lib/middleware is excluded from
# autoloading; a middleware must exist before the app boots).
#
# Notes:
#   * The root "/" is left alone.
#   * Only GET and HEAD are redirected; a POST to "/contact/" is not rewritten.
#   * /assets, /rails (Active Storage, Action Mailbox) and /admin are skipped.
#   * The Location is a path, not an absolute URL, so it keeps whatever scheme and host
#     the client used. Leading slashes are collapsed so "//evil.example/" can never turn
#     into a protocol-relative redirect to another host.
#   * It sits after ActionDispatch::SSL, so an http request is first sent to https (by
#     SSL) and then, if it has a trailing slash, to the clean path: two hops at most.
#     (Bare-domain requests are handled one step earlier by CanonicalHostRedirect.)
module Middleware
  class TrailingSlashRedirect
    SKIPPED_PREFIXES = %w[/assets/ /rails/ /admin/ /cable/ /up/].freeze

    def initialize(app)
      @app = app
    end

    # The redirect target path ("/path/" -> "/path"), or nil when this request is not one the
    # middleware rewrites. Shared with Middleware::CanonicalHostRedirect so an apex request
    # with a trailing slash is cleaned in the same single redirect.
    def self.clean_path(env)
      return nil unless redirect?(env)

      path = env["PATH_INFO"].to_s
      path = path.b unless path.valid_encoding? # a mangled path must not raise in the regexes
      path = path.sub(%r{/+\z}, "").sub(%r{\A/+}, "/")
      path.empty? ? "/" : path
    end

    def self.redirect?(env)
      return false unless %w[GET HEAD].include?(env["REQUEST_METHOD"])
      path = env["PATH_INFO"].to_s
      return false unless path.end_with?("/")
      return false if path == "/"
      !SKIPPED_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end

    def call(env)
      path = self.class.clean_path(env)
      return @app.call(env) unless path

      query = env["QUERY_STRING"].to_s
      location = "#{env['SCRIPT_NAME']}#{path}"
      location = "#{location}?#{query}" unless query.empty?

      [301, { "location" => location, "content-type" => "text/html; charset=utf-8", "content-length" => "0" }, []]
    end
  end
end
