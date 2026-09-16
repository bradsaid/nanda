# Solid Queue is now provisioned (see db/migrate/*_install_solid_queue.rb), so
# the adapter is set per-environment in config/environments/*.rb rather than
# being forced here. This file previously pinned production to :async because
# the queue tables did not exist yet; leaving that in place would silently
# override the environment setting, since initializers load after it.
