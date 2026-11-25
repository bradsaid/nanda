# Image helpers shared by the layout and views.
module SiteImagesHelper
  # Header banner. NAKED.png is 1200x674 / 494 KB and is the Largest Contentful
  # Paint element on every page, so it is served as AVIF/WebP at 400/800/1200w
  # (app/assets/images/NAKED-<w>.{avif,webp}) with the PNG kept as the fallback.
  # CSS (.site-banner) sets the displayed size and crops it; the width/height
  # attributes just reserve the aspect ratio. Never lazy-load it.
  BANNER_WIDTHS = [ 400, 800, 1200 ].freeze
  BANNER_WIDTH  = 1200
  BANNER_HEIGHT = 674
  # The banner fills its container up to 1200px wide.
  BANNER_SIZES  = "(max-width: 1200px) 100vw, 1200px".freeze
  BANNER_ALT    = "Naked and Afraid Fan Database".freeze

  # "/assets/NAKED-400-<digest>.avif 400w, ..." for the given format.
  def banner_srcset(format)
    BANNER_WIDTHS.map { |w| "#{asset_path("NAKED-#{w}.#{format}")} #{w}w" }.join(", ")
  end

  def site_banner_tag
    tag.picture do
      safe_join([
        tag.source(type: "image/avif", srcset: banner_srcset("avif"), sizes: BANNER_SIZES),
        tag.source(type: "image/webp", srcset: banner_srcset("webp"), sizes: BANNER_SIZES),
        image_tag("NAKED.png",
                  alt: BANNER_ALT, class: "site-banner",
                  width: BANNER_WIDTH, height: BANNER_HEIGHT,
                  fetchpriority: "high", decoding: "async")
      ])
    end
  end

  # <link rel="preload"> for the banner so the browser fetches it in parallel
  # with the CSS. Only the AVIF candidate is preloaded (the `type` makes browsers
  # without AVIF support skip it and fall back to the <picture> choice), and it
  # uses the same srcset/sizes as the <source> so the same file is picked.
  # Preload links are not scripts, so CSP is unaffected.
  def site_banner_preload_tag
    tag.link(rel: "preload", as: "image", type: "image/avif",
             imagesrcset: banner_srcset("avif"), imagesizes: BANNER_SIZES,
             fetchpriority: "high")
  end
end
