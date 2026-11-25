# Open Graph / Twitter Card images, emitted once by the layout (share_image_meta_tags).
#
# Scrapers (Facebook, X, Slack, iMessage, Google Discover) need an absolute URL on the
# canonical host that keeps working after the page is cached, so:
#   * the host is CANONICAL_ORIGIN, never request.host (which can be the herokuapp one);
#   * attached survivor avatars go through Active Storage's PROXY route
#     (/rails/active_storage/representations/proxy/...). Its signed blob id carries no
#     expiry (we pass expires_in: nil explicitly) and it streams the bytes itself with
#     `Cache-Control: public, max-age=100 years`. The default redirect route is also
#     stable, but it answers 302 -> a 5-minute presigned S3 URL, which some scrapers
#     cache or refuse to follow.
#   * a record with no image falls back to the site artwork, app/assets/images/share-default.jpg.
#
# Views opt in with `content_for :og_image` (+ :og_image_width / :og_image_height /
# :og_image_alt, optionally :twitter_image) or the set_share_image helper below; pages that
# say nothing get the default.
module ShareImageHelper
  CANONICAL_ORIGIN = ENV.fetch("CANONICAL_ORIGIN", "https://www.nakedandafraidfan.com").chomp("/").freeze

  DEFAULT_SHARE_IMAGE      = "share-default.jpg".freeze
  DEFAULT_SHARE_IMAGE_SIZE = [ 1200, 630 ].freeze
  DEFAULT_SHARE_IMAGE_ALT  = "Naked and Afraid Fan Database: every episode, survivor, item and location in one place".freeze

  # Survivor.avatar's :share variant (see Survivor). Square, so it is shown uncropped.
  AVATAR_SHARE_SIZE = [ 600, 600 ].freeze
  # An image at least this much wider than tall is worth a "large image" Twitter card.
  LARGE_CARD_MIN_RATIO = 1.5

  # Absolute canonical-host URL for a site path ("/assets/x.jpg"); full URLs pass through.
  def canonical_asset_url(path_or_url)
    value = path_or_url.to_s.strip
    return value if value.match?(%r{\Ahttps?://}i)
    "#{CANONICAL_ORIGIN}#{value.start_with?('/') ? value : "/#{value}"}"
  end

  # The default share image as { url:, width:, height:, alt: }. asset_path is the
  # fingerprinted Propshaft path (/assets/share-default-<digest>.jpg).
  def default_share_image
    { url: canonical_asset_url(asset_path(DEFAULT_SHARE_IMAGE)),
      width: DEFAULT_SHARE_IMAGE_SIZE[0], height: DEFAULT_SHARE_IMAGE_SIZE[1],
      alt: DEFAULT_SHARE_IMAGE_ALT }
  end

  # Permanent absolute URL of an attached Active Storage attachment or variant through the
  # proxy route, or nil when nothing is attached.
  def permanent_storage_url(attachment_or_variant)
    return nil if attachment_or_variant.nil?
    return nil if attachment_or_variant.respond_to?(:attached?) && !attachment_or_variant.attached?
    "#{CANONICAL_ORIGIN}#{rails_storage_proxy_path(attachment_or_variant, expires_in: nil)}"
  rescue StandardError
    nil
  end

  # { url:, width:, height:, alt: } for a record with an `avatar` (a Survivor) or nil.
  def avatar_share_image(survivor)
    return nil unless survivor&.avatar&.attached?
    url = permanent_storage_url(survivor.avatar.variant(:share))
    return nil unless url
    { url: url, width: AVATAR_SHARE_SIZE[0], height: AVATAR_SHARE_SIZE[1],
      alt: "#{survivor.full_name}, Naked and Afraid survivor" }
  end

  # For a view: sets the page's share image through the content_for hooks the layout reads.
  # A nil image (record without one) leaves the default in place.
  def set_share_image(image)
    return if image.blank? || image[:url].blank?
    content_for :og_image, image[:url]
    content_for :og_image_width, image[:width].to_s if image[:width]
    content_for :og_image_height, image[:height].to_s if image[:height]
    content_for :og_image_alt, image[:alt] if image[:alt].present?
    nil
  end

  # The og:image / twitter:image tag group, exactly one of each, always absolute.
  def share_image_meta_tags
    if content_for?(:og_image)
      og_url = canonical_asset_url(content_for(:og_image))
      width  = content_for?(:og_image_width)  ? content_for(:og_image_width).to_s.to_i  : nil
      height = content_for?(:og_image_height) ? content_for(:og_image_height).to_s.to_i : nil
      alt    = content_for?(:og_image_alt)    ? content_for(:og_image_alt).to_s         : nil
      tw_url = content_for?(:twitter_image)   ? canonical_asset_url(content_for(:twitter_image)) : og_url
    else
      d = default_share_image
      og_url, width, height, alt = d[:url], d[:width], d[:height], d[:alt]
      tw_url = og_url
    end
    width  = nil unless width.to_i.positive?
    height = nil unless height.to_i.positive?
    large  = width && height ? (width.to_f / height) >= LARGE_CARD_MIN_RATIO : true

    tags = []
    tags << tag.meta(property: "og:image", content: og_url)
    tags << tag.meta(property: "og:image:width", content: width) if width
    tags << tag.meta(property: "og:image:height", content: height) if height
    tags << tag.meta(property: "og:image:alt", content: alt) if alt.present?
    tags << tag.meta(name: "twitter:card", content: large ? "summary_large_image" : "summary")
    tags << tag.meta(name: "twitter:image", content: tw_url)
    tags << tag.meta(name: "twitter:image:alt", content: alt) if alt.present?
    safe_join(tags, "\n")
  end
end
