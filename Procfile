release: bundle exec rails db:migrate && bundle exec rake sitemap:refresh:no_ping
web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
