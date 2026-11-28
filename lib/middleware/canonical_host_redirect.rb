# Permanently redirects every request for the bare domain (nakedandafraidfan.com) to the
# canonical https://www.nakedandafraidfan.com, keeping the path and query string.
#
# Why: DNS at GoDaddy only forwards the apex ROOT, so https://nakedandafraidfan.com/about
# (and every other deep link) never reached the app. Once the apex points at Heroku (see the
# DNS notes in the commit/report), this middleware answers those requests itself.
#
# Placement (config/application.rb): first in the stack, ahead of ActionDispatch::SSL and
# Middleware::TrailingSlashRedirect. Because it always targets https://www, an http apex
# request is redirected once, not http -> https -> www. A trailing slash is dropped in the
# same hop (using TrailingSlashRedirect's rules), so the chain is a single redirect.
#
# Only the exact host "nakedandafraidfan.com" (case-insensitive, optional port or trailing
# dot) is touched. www, *.herokuapp.com, localhost, the test host and requests with no Host
# at all pass straight through.
#
# GET/HEAD get a 301; any other method gets a 308 so the method and body survive the hop.
#
# The Location is built from percent-encoded bytes only (anything outside printable ASCII
# is escaped), so a malformed or hostile path can never inject a header line or raise.
module Middleware
  class CanonicalHostRedirect
    APEX_HOST = "nakedandafraidfan.com".freeze
    CANONICAL_ORIGIN = "https://www.nakedandafraidfan.com".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless apex?(env)

      path = env["PATH_INFO"].to_s
      path = TrailingSlashRedirect.clean_path(env) || path
      path = "/#{path}" unless path.start_with?("/")
      location = "#{CANONICAL_ORIGIN}#{escape(env['SCRIPT_NAME'].to_s + path)}"
      query = env["QUERY_STRING"].to_s
      location = "#{location}?#{escape(query)}" unless query.empty?

      status = %w[GET HEAD].include?(env["REQUEST_METHOD"]) ? 301 : 308
      [ status, { "location" => location, "content-type" => "text/html; charset=utf-8", "content-length" => "0" }, [] ]
    end

    private

    def apex?(env)
      host = (env["HTTP_HOST"] || env["SERVER_NAME"]).to_s.b.downcase
      host = host.sub(/:\d+\z/, "").chomp(".")
      host == APEX_HOST
    end

    # Escape every byte that is not printable ASCII (controls, space, DEL, high bytes) while
    # leaving existing %XX escapes and URL punctuation alone.
    def escape(value)
      value.b.gsub(/[^\x21-\x7E]/n) { |byte| format("%%%02X", byte.ord) }
    end
  end
end
