release: bundle exec rails db:migrate && bundle exec rake sitemap:refresh:no_ping
web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
# Solid Queue on its own dyno rather than forked inside Puma. In-Puma cost the
# web dyno four extra Ruby processes and put it ~63MB over a 512MB quota,
# steady-state, with the difference going to swap.
worker: bundle exec rails solid_queue:start
