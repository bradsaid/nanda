# Keeps account-only and low-value pages (sign in/up, password reset, email
# confirmation, forum composers, ...) out of search results.
#
#   class SessionsController < ApplicationController
#     noindex                                   # every action
#     noindex only: %i[new create]              # filter options work as for before_action
#     noindex "noindex, follow", only: :index   # let crawlers follow links but not index
#   end
#
# It emits BOTH the `X-Robots-Tag` response header and (via the layout) a
# `<meta name="robots">` tag. A page can still set its own robots meta with
# `content_for :robots`; that wins for the meta tag.
module Noindexable
  extend ActiveSupport::Concern

  DEFAULT_ROBOTS = "noindex, nofollow".freeze

  class_methods do
    def noindex(value = DEFAULT_ROBOTS, **filter_options)
      before_action(**filter_options) { set_robots(value) }
    end
  end

  private

  def set_robots(value = DEFAULT_ROBOTS)
    @robots_meta = value
    response.set_header("X-Robots-Tag", value)
  end
end
