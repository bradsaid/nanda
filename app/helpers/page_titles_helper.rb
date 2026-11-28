# <title> templates for the page types that build them from a record's name, each as a list of
# candidates, richest first, handed to SeoHelper#fitted_title (cap: SeoHelper::MAX_TITLE_LENGTH).
# The first candidate that fits wins, so a short name keeps the full wording and a long one
# falls back deterministically to the next, always keeping the key entity (the survivor,
# item, country, series/season/episode) and dropping qualifiers first:
#
#   "Ann Alpha – Naked and Afraid Survivor"  ->  "Ann Alpha – Naked and Afraid"  ->  "Ann Alpha"
#
# Episode, season, series and region titles live in FranchiseHelper / RegionsHelper and use
# the same mechanism.
module PageTitlesHelper
  def survivor_page_title(name)
    fitted_title("#{name} – Naked and Afraid Survivor", "#{name} – Naked and Afraid", name)
  end

  # `country` is the ?country= filter, when there is one.
  def item_page_title(name, country: nil)
    if country.present?
      fitted_title("#{name} – Naked and Afraid Item — in #{country}",
                 "#{name} – Naked and Afraid Item in #{country}",
                 "#{name} in #{country} – Naked and Afraid",
                 "#{name} in #{country}",
                 name)
    else
      fitted_title("#{name} – Naked and Afraid Item", "#{name} – Naked and Afraid", name)
    end
  end

  def item_type_page_title(type, country: nil)
    if country.present?
      fitted_title("#{type} Items – Naked and Afraid — in #{country}",
                 "#{type} Items – Naked and Afraid in #{country}",
                 "#{type} Items in #{country}",
                 "#{type} Items",
                 type)
    else
      fitted_title("#{type} Items – Naked and Afraid", "#{type} Items", type)
    end
  end

  def country_episodes_title(country, page: nil)
    fitted_title("Naked and Afraid Episodes in #{country}", "Naked and Afraid in #{country}", "Episodes in #{country}", country, page: page)
  end

  def food_source_page_title(food_name)
    fitted_title("#{food_name} – Naked and Afraid Food Source", "#{food_name} – Naked and Afraid Food", "#{food_name} – Naked and Afraid", food_name)
  end

  def shelter_page_title(type)
    fitted_title("#{type} – Naked and Afraid Shelter", "#{type} – Naked and Afraid", type)
  end

  # /episodes?location_id=N: the site, region and country, dropping the most specific part first.
  def location_episodes_title(location)
    site, region, country = location.site.presence, location.region.presence, location.country.presence
    names = [ [ site, region, country ], [ region, country ], [ country ], [ site, region ], [ site ], [ region ] ]
              .map(&:compact).reject(&:empty?).map { |parts| parts.join(", ") }.uniq
    names = [ "Unknown Location" ] if names.empty?
    fitted_title(*names.map { |n| "Naked and Afraid Episodes in #{n}" },
                 *names.map { |n| "Naked and Afraid in #{n}" },
                 *names.map { |n| "Episodes in #{n}" })
  end

  # /episodes?season_id=N (the season's episode guide).
  def season_episodes_title(series_name, season_number)
    full = "#{series_name} – Season #{season_number} (Episode Guide)"
    short_series = series_name.to_s.sub(/\ANaked and Afraid[: ]+/i, "").presence
    fitted_title(full, "#{series_name} – Season #{season_number}", "#{series_name} Season #{season_number}",
               ("#{short_series} – Season #{season_number}" if short_series))
  end

  # "Topic title — Forum": the topic's own title is the entity, so the suffix goes first and the
  # title itself is only cut (at a word boundary) when it alone is too long.
  def forum_topic_title(topic_title, page: nil)
    fitted_title("#{topic_title} — Forum", topic_title, page: page)
  end
end
