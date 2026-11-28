# THIN-CONTENT POLICY: the one place that decides which pages are too thin to be offered to
# search engines. A page below its bar still renders for visitors (nothing is hidden or
# removed); it is served with `noindex, follow` (<meta name="robots"> plus the X-Robots-Tag
# header, see Noindexable) and is left out of /sitemap.xml (SitemapUrls).
#
# FLAGS BRAD CAN FLIP (Heroku config vars; a dyno restart picks them up):
#
#   NOINDEX_THIN_EPISODES=false    index episode pages even when they have no synopsis
#                                  (default: true, i.e. episodes without a synopsis are noindexed)
#   THIN_FOOD_SOURCE_MIN_EPISODES  food source pages linked to fewer episodes than this are
#                                  noindexed (default 2; 0 or 1 turns the rule off)
#   THIN_SHELTER_MIN_EPISODES      same for shelter pages (default 2)
#
# "Without a synopsis" means blank after tags, entities and whitespace are stripped, so a
# synopsis of "   " or "<p></p>" counts as missing. The admin synopsis queue
# (/admin/synopsis_queue, "Missing") lists exactly these episodes: it uses the same
# Episode.without_synopsis scope.
module ThinContent
  DEFAULT_MIN_EPISODES = 2

  class << self
    # Episodes with no synopsis are noindexed unless NOINDEX_THIN_EPISODES is turned off.
    def noindex_episodes_without_synopsis?
      !%w[false 0 no off].include?(ENV.fetch("NOINDEX_THIN_EPISODES", "true").to_s.strip.downcase)
    end

    def food_source_min_episodes = min_episodes("THIN_FOOD_SOURCE_MIN_EPISODES")
    def shelter_min_episodes     = min_episodes("THIN_SHELTER_MIN_EPISODES")

    # A food source / shelter page is thin when fewer episodes than the minimum are linked.
    def thin_food_source?(episode_count) = episode_count.to_i < food_source_min_episodes
    def thin_shelter?(episode_count)     = episode_count.to_i < shelter_min_episodes

    # Part of the sitemap cache key: flipping a flag or threshold must rebuild the cached XML.
    def cache_stamp
      [noindex_episodes_without_synopsis?, food_source_min_episodes, shelter_min_episodes].join(",")
    end

    private

    def min_episodes(name)
      Integer(ENV.fetch(name, DEFAULT_MIN_EPISODES).to_s, exception: false)&.clamp(0, 1000) || DEFAULT_MIN_EPISODES
    end
  end
end
