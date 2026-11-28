# Self-hosted Montserrat (SIL Open Font License 1.1), latin subset, as variable fonts:
# one upright file covers weights 400-900 and one italic file covers 400-600, which is every
# weight the site CSS and Bootstrap use. Files live in app/assets/fonts/ and are served by
# Propshaft with a digest. The unicode-range is Google Fonts' own "latin" range, so
# characters outside it (Cyrillic, Vietnamese, Latin Extended) fall back to the system
# font exactly as before; no survivor/episode name in the repo needs Latin Extended.
module FontsHelper
  LATIN_RANGE = "U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, " \
                "U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, " \
                "U+2215, U+FEFF, U+FFFD".freeze

  MONTSERRAT_UPRIGHT = "montserrat-latin-wght.woff2".freeze
  MONTSERRAT_ITALIC  = "montserrat-italic-latin-wght.woff2".freeze

  # <link rel="preload"> for the font the first paint needs (upright, all weights). The
  # crossorigin attribute is required for font preloads even on the same origin, or the
  # browser fetches the file twice.
  def font_preload_tag
    tag.link(rel: "preload", as: "font", type: "font/woff2", crossorigin: "anonymous",
             href: font_path(MONTSERRAT_UPRIGHT))
  end

  # Inline <style> with the @font-face rules (no extra stylesheet request on the critical
  # path). font-display: swap shows the fallback stack immediately and swaps when loaded.
  def font_face_style_tag
    tag.style(font_face_css.html_safe)
  end

  def font_face_css
    [ [ "normal", "400 900", MONTSERRAT_UPRIGHT ], [ "italic", "400 600", MONTSERRAT_ITALIC ] ].map do |style, weight, file|
      "@font-face{font-family:\"Montserrat\";font-style:#{style};font-weight:#{weight};font-display:swap;" \
        "src:url(#{font_path(file)}) format(\"woff2\");unicode-range:#{LATIN_RANGE}}"
    end.join("\n")
  end
end
