require_relative "boot"

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
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Central Time (US & Canada)"

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
