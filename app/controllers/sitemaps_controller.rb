# GET /sitemap.xml, built from the database (see SitemapUrls) instead of a file in public/.
#
# Inherits from ActionController::Base on purpose: crawlers must always get the XML, so none
# of ApplicationController's browser gate, page-view tracking or session handling applies.
class SitemapsController < ActionController::Base
  CACHE_TTL = 1.hour

  def show
    xml = Rails.cache.fetch(SitemapUrls.cache_key, expires_in: CACHE_TTL) { SitemapUrls.to_xml }

    expires_in CACHE_TTL, public: true
    if stale?(etag: Digest::SHA256.hexdigest(xml), public: true)
      render xml: xml
    end
  end
end
