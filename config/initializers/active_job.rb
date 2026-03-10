# SolidQueue tables are not provisioned on Heroku.
# Force :async so ActiveStorage::AnalyzeJob (and others) don't crash.
Rails.application.config.active_job.queue_adapter = :async if Rails.env.production?
