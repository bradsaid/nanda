require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Durable, out-of-process jobs. The earlier attempt at this crash-looped the
  # dyno; the cause turned out to be the database pool being pinned to Puma's
  # thread count, so Solid Queue refused to boot and the Puma plugin stopped
  # Puma in response. config/database.yml now sizes the pool independently, and
  # the supervisor was verified starting cleanly on a one-off dyno before this
  # was switched back on.
  #
  # Jobs only actually run once SOLID_QUEUE_IN_PUMA is set; until then they
  # enqueue durably and wait, rather than being lost as they were under :async.
  config.active_job.queue_adapter = :solid_queue

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.


  # www, not the bare domain. The apex still points at three retired Heroku
  # IPs: http:// there answers with a 301, but https:// times out entirely —
  # so every verification and password-reset link built on the apex was a dead
  # link. Only www.nakedandafraidfan.com resolves to the live app.
  config.action_mailer.default_url_options = {
    host:     ENV.fetch("MAILER_HOST", "www.nakedandafraidfan.com"),
    protocol: "https"
  }
  config.action_mailer.delivery_method = :smtp

  # Env-driven so moving to Google Workspace is a config change, not a deploy.
  # SMTP_DOMAIN is the HELO domain and should match the sending domain once
  # Workspace is live. SMTP_USERNAME/SMTP_PASSWORD fall back to the old
  # GMAIL_* names so nothing breaks before the switch.
  config.action_mailer.smtp_settings = {
    address:              ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"),
    port:                 ENV.fetch("SMTP_PORT", 587).to_i,
    domain:               ENV.fetch("SMTP_DOMAIN", "gmail.com"),
    user_name:            ENV["SMTP_USERNAME"] || ENV["GMAIL_USERNAME"],
    password:             ENV["SMTP_PASSWORD"] || ENV["GMAIL_APP_PASSWORD"],
    authentication:       "plain",
    enable_starttls_auto: true
  }



  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  config.active_storage.service = :amazon
end
