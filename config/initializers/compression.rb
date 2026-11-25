# Gzip text responses (HTML, CSS, JS, JSON, XML incl. the sitemap, SVG, plain
# text). No Content-Encoding was being sent at all, so every page and asset went
# out uncompressed.
#
# Rack::Deflater ships with Rack, so no gem is needed. (Brotli would need the
# rack-brotli gem; gzip captures most of the win and keeps the deploy gem-free.)
#
# It sits at the front of the stack (ahead of Rack::Sendfile and
# ActionDispatch::Static) so fingerprinted CSS/JS served from public/assets are
# compressed too. Rack::Deflater already sets `Vary: Accept-Encoding`, skips
# responses that are empty, 204/304, `Cache-Control: no-transform`, or already
# encoded. The condition below additionally leaves alone:
#   * anything that isn't a compressible text type (images, video, fonts, PDFs,
#     zips are already compressed or gain nothing),
#   * text/event-stream (ActionController::Live / SSE must flush untouched),
#   * 206 Partial Content / Content-Range responses (byte ranges would be corrupted).
#
# ETag / conditional GET is unaffected: Rack::ETag and Rack::ConditionalGet sit
# inside Deflater and answer 304s (never compressed) from the uncompressed body.
module NandaCompression
  COMPRESSIBLE = %r{
    \A(?:
      text/(?!event-stream)[^;\s]+ |
      application/(?:json|javascript|ecmascript|xml|xhtml\+xml|manifest\+json|ld\+json|x-ndjson|(?:[\w.+-]+\+(?:json|xml))) |
      image/svg\+xml |
      font/(?:ttf|otf|sfnt) |
      application/(?:x-font-ttf|vnd\.ms-fontobject)
    )\z
  }ix

  def self.compress?(_env, status, headers, _body)
    h = headers.transform_keys { |k| k.to_s.downcase }
    return false if status.to_i == 206 || h["content-range"]

    type = h["content-type"].to_s.split(";").first.to_s.strip
    COMPRESSIBLE.match?(type)
  end
end

Rails.application.config.middleware.insert_before Rack::Sendfile, Rack::Deflater, if: NandaCompression.method(:compress?)
