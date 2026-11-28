require_relative "boot"
require_relative "../lib/middleware/trailing_slash_redirect"
require_relative "../lib/middleware/canonical_host_redirect"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Nakedandafraid
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # "/forum/" and every other trailing-slash URL 301s to the unslashed path. Placed right
    # before Rack::Sendfile, i.e. after host authorization and force_ssl's https redirect
    # but ahead of static files and the router (see lib/middleware/trailing_slash_redirect.rb).
    config.middleware.insert_before Rack::Sendfile, Middleware::TrailingSlashRedirect

    # nakedandafraidfan.com/<anything> 301s to https://www.nakedandafraidfan.com/<anything>.
    # First in the stack (ahead of force_ssl's ActionDispatch::SSL), so http://nakedandafraidfan.com/x
    # reaches https://www in ONE hop instead of http -> https -> www. Every other host
    # (www, *.herokuapp.com, localhost, the test host) passes straight through.
    config.middleware.insert_before 0, Middleware::CanonicalHostRedirect

    config.time_zone = "Central Time (US & Canada)"

    # Branded 404/422/500 (and other error) pages through the site layout instead
    # of the static public/*.html files. ErrorsController falls back to those
    # static files itself if the full layout cannot render. No routes involved:
    # ShowExceptions rewrites PATH_INFO to "/<status>" before calling this.
    config.exceptions_app = ->(env) { ErrorsController.action(:show).call(env) }

    # Every image_tag defaults to loading="lazy" decoding="async" (below-the-fold
    # avatars, shop products, flags, ...). image_tag only applies these when the
    # call doesn't pass its own, so nothing is doubled. Above-the-fold images
    # opt out with `loading: "eager"` (site banner, a survivor's main portrait,
    # hero flags, the signed-in nav avatar).
    config.action_view.image_loading  = "lazy"
    config.action_view.image_decoding = "async"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
