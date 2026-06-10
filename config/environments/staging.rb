require "active_support/core_ext/integer/time"
require_relative "../canonical_app_host"

Rails.application.configure do
  # Staging should behave like production unless a staging-only integration
  # intentionally differs.
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Match production infrastructure on Heroku.
  config.active_storage.service = :bucketeer
  config.assume_ssl = true
  config.force_ssl = true

  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Capture staging email in the app instead of sending real messages.
  config.action_mailer.delivery_method = :letter_opener_web
  config.action_mailer.raise_delivery_errors = true

  app_host = CanonicalAppHost.normalize(ENV.fetch("APP_HOST", "staging.cragmontclimbing.com"))
  config.action_mailer.default_url_options = { host: app_host, protocol: "https" }
  Rails.application.routes.default_url_options = { host: app_host, protocol: "https" }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  config.hosts << app_host
  config.hosts << /.*\.herokuapp\.com/
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
