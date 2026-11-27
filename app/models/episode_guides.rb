# The localized landing pages (/es, /pt, /fr ...naked-and-afraid episode guide). One place
# for the language => path table used by the routes' tests, the hreflang alternates, the
# language switcher, the footer and the sitemap. Copy lives in config/locales/landing_*.yml.
module EpisodeGuides
  PATHS = {
    "es" => "/es/naked-and-afraid-guia-de-episodios",
    "pt" => "/pt/naked-and-afraid-guia-de-episodios",
    "fr" => "/fr/naked-and-afraid-guide-des-episodes"
  }.freeze

  LANGS = PATHS.keys.freeze

  # The English page the alternates point x-default at.
  DEFAULT_PATH = "/series".freeze

  def self.path(lang)
    PATHS.fetch(lang.to_s)
  end

  def self.lang?(lang)
    PATHS.key?(lang.to_s)
  end
end
