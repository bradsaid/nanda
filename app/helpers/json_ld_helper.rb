# app/helpers/json_ld_helper.rb
module JsonLdHelper
  # Returns a JSON string for episodes index schema module to consume
  # Usage from view:
  #   episodes_index_json_payload(location: @location, episodes: @episodes, season: @season, episodes_by_season: @episodes_by_season, episode_counts: @episode_counts)
  def episodes_index_json_payload(location:, episodes:, season:, episodes_by_season:, episode_counts:)
    simplify = ->(ep) {
      {
        name:     (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        url:      episode_path(ep),
        series:   ep.season&.series&.name,
        season:   ep.season&.number,
        number:   ep.number_in_season,
        air_date: ep.air_date&.strftime("%Y-%m-%d"),
        location: [ep.location&.country, ep.location&.region, ep.location&.site].compact_blank.join(", ").presence
      }
    }

    if location.present?
      loc_name = [location.site, location.region, location.country].compact_blank.join(", ").presence || "Unknown Location"
      list = Array(episodes).first(20).map(&simplify)
      payload = {
        name: "Episodes in #{loc_name}",
        count: Array(episodes).size,
        description: "Episodes filmed in #{loc_name}.",
        episodes: list
      }
    elsif season.present?
      series_name = season.series&.name || "Naked and Afraid"
      title_txt   = "#{series_name} – Season #{season.number}"
      list = Array(episodes).first(20).map(&simplify)
      payload = {
        name: "#{title_txt} Episodes",
        count: Array(episodes).size,
        description: "Episodes for #{title_txt}.",
        episodes: list
      }
    else
      ep_counts   = (episode_counts || {})
      total_count = ep_counts.values.map(&:to_i).sum
      sample_eps  = (episodes_by_season || {}).values.flatten.first(20)
      payload = {
        name: "Naked and Afraid Episodes",
        count: total_count,
        description: "Episode guide organized by season.",
        episodes: Array(sample_eps).map(&simplify)
      }
    end

    JSON.generate(payload)
  end

  def episode_show_json_payload(episode)
    series_name  = episode.season&.series&.name
    season_num   = episode.season&.number
    ep_num       = episode.number_in_season
    air_iso      = episode.air_date&.to_date
    loc          = episode.location
    location_str = [loc&.country, loc&.region, loc&.site].compact_blank.join(", ").presence

    actors = Array(episode.survivors).map { |s| { name: s.full_name, url: survivor_path(s) } }

    # If any survivor has an avatar attached, use the first as preview image (path-only to avoid host requirement)
    image_url =
      episode.appearances
             .map { |a| a.survivor }
             .find { |s| s&.avatar&.attached? }
             &.yield_self { |s| rails_blob_path(s.avatar, only_path: true) } rescue nil

    JSON.generate({
      title:          (episode.title.presence || "Episode"),
      series_name:    series_name,
      season_number:  season_num,
      episode_number: ep_num,
      air_date_iso:   air_iso,
      location:       location_str,
      actors:         actors,
      image:          image_url
    })
  end

  def episodes_by_country_json_payload(country:, episodes:)
    simplify = ->(ep) {
      {
        name:     (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        url:      episode_path(ep),
        series:   ep.season&.series&.name,
        season:   ep.season&.number,
        number:   ep.number_in_season,
        air_date: ep.air_date&.strftime("%Y-%m-%d"),
        location: [ep.location&.country, ep.location&.region, ep.location&.site].compact_blank.join(", ").presence
      }
    }
    payload = {
      country:  country.to_s,
      count:    Array(episodes).size,
      episodes: Array(episodes).first(20).map(&simplify)
    }
    JSON.generate(payload)
  end

  def item_show_json_payload(item:, given_ai:, brought_ai:, country:)
    simplify_episode = ->(ep) {
      {
        name:   (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        url:    episode_path(ep),
        series: ep.season&.series&.name,
        season: ep.season&.number,
        number: ep.number_in_season
      }
    }

    given_eps_ids   = Array(given_ai).map { |ai| ai.appearance&.episode_id }.compact.uniq
    brought_eps_ids = Array(brought_ai).map { |ai| ai.appearance&.episode_id }.compact.uniq
    total_ids       = (given_eps_ids + brought_eps_ids).uniq

    # sample up to 10 distinct episodes appearing for this item
    episodes = ((Array(given_ai) + Array(brought_ai)).map { |ai| ai.appearance&.episode }.compact.uniq)
                .first(10).map(&simplify_episode)

    JSON.generate({
      name:     item.name.to_s,
      category: (item.respond_to?(:item_type) ? item.item_type : nil),
      given:    given_eps_ids.size,
      brought:  brought_eps_ids.size,
      total:    total_ids.size,
      country:  country.presence,
      episodes: episodes
    })
  end

  def item_type_json_payload(item_type:, country:, items_in_type_count:, given_episode_ids:, brought_episode_ids:, given_ai:, brought_ai:)
    # Sample up to 10 distinct items shown on the page
    items = ((Array(given_ai) + Array(brought_ai)).map(&:item).compact.uniq)
              .first(10)
              .map { |it| { name: it.name, url: item_path(it) } }

    JSON.generate({
      type:        item_type.to_s,
      country:     country.presence,
      items_count: items_in_type_count.to_i,
      given:       Array(given_episode_ids).uniq.size,
      brought:     Array(brought_episode_ids).uniq.size,
      items:       items
    })
  end

  # JSON for Seasons index (consumed by json_ld/seasons_index.js)
  def seasons_index_json_payload(seasons:)
    seasons = Array(seasons)
    sample = seasons.first(20).map do |s|
      {
        url:      season_path(s),
        name:     "#{s.series&.name} – Season #{s.number}",
        series:   s.series&.name,
        number:   s.number,
        episodes: (s.respond_to?(:episodes) ? s.episodes.size : nil)
      }
    end
    JSON.generate({ total_seasons: seasons.size, sample: sample })
  end

  # JSON string for Season show page; consumed by json_ld/season_show.js
  def season_show_json_payload(season:, episodes:)
    series_name = season.series&.name
    season_num  = season.number

    episodes_simplified = Array(episodes).first(20).map do |ep|
      {
        name:     (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        url:      episode_path(ep),
        number:   ep.number_in_season,
        air_date: ep.air_date&.strftime("%Y-%m-%d"),
        location: [ep.location&.country, ep.location&.region, ep.location&.site].compact_blank.join(", ").presence,
        series:   ep.season&.series&.name
      }
    end

    JSON.generate({
      series_name:   series_name,
      season_number: season_num,
      episode_count: Array(episodes).size,
      episodes:      episodes_simplified
    })
  end

  def survivors_index_json_payload(top_survivors:, survivors:)
    list = (Array(top_survivors).presence || Array(survivors)).first(20)

    simplified = list.map do |s|
      total     = s.respond_to?(:episodes_total_count)     ? s.episodes_total_count.to_i     : s.appearances.select(:episode_id).distinct.count
      collapsed = s.respond_to?(:episodes_collapsed_count) ? s.episodes_collapsed_count.to_i : total

      img = if s.respond_to?(:avatar) && s.avatar&.attached?
              rails_blob_path(s.avatar, only_path: true) rescue nil
            end

      {
        name:            s.try(:full_name) || s.try(:name) || "Survivor ##{s.id}",
        url:             survivor_path(s),
        image:           img,
        episodes_total:  total,
        challenges:      collapsed
      }
    end

    JSON.generate({
      count:     list.size,
      survivors: simplified
    })
  end

  def survivor_show_json_payload(survivor:, appearances:)
    img =
      if survivor.respond_to?(:avatar) && survivor.avatar&.attached?
        rails_blob_path(survivor.avatar, only_path: true) rescue nil
      end

    social = []
    if survivor.respond_to?(:instagram) && survivor.instagram.present?
      handle = survivor.instagram.to_s.strip
      handle = handle.sub(/\A@/, '')
      handle = handle.sub(%r{\Ahttps?://(www\.)?instagram\.com/}i, '').sub(%r{/.*$}, '')
      social << "https://www.instagram.com/#{handle}"
    end
    if survivor.respond_to?(:facebook) && survivor.facebook.present?
      handle = survivor.facebook.to_s.strip
      handle = handle.sub(/\A@/, '')
      handle = handle.sub(%r{\Ahttps?://(www\.)?facebook\.com/}i, '').sub(%r{/.*$}, '')
      social << "https://www.facebook.com/#{handle}"
    end

    eps = Array(appearances).map do |a|
      ep = a.episode
      next unless ep
      {
        name:     (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        url:      episode_path(ep),
        series:   ep.season&.series&.name,
        season:   ep.season&.number,
        number:   ep.number_in_season,
        air_date: ep.air_date&.strftime("%Y-%m-%d"),
        location: [ep.location&.country, ep.location&.region, ep.location&.site].compact_blank.join(", ").presence,
        days:     a.days_lasted,
        psr:      [a.starting_psr, a.ending_psr].compact.join(" → ").presence,
        result:   a.result.presence
      }
    end.compact.first(20)

    JSON.generate({
      name:             survivor.full_name.to_s,
      url:              survivor_path(survivor),
      image:            img,
      sameAs:           social,
      episodes_total:   survivor.appearances.select(:episode_id).distinct.count,
      challenges:       (survivor.respond_to?(:episodes_collapsed_count) ? survivor.episodes_collapsed_count.to_i : nil),
      episodes:         eps
    })
  end

  def podcasts_books_json_payload(ky:)
    podcasts = [
      { name: "Oh Heck NAA - A Naked and Afraid Podcast",
        urls: [
          "https://open.spotify.com/show/2q2ZfSDQiL6u26dV4o2fNN",
          "https://podcasts.apple.com/us/podcast/a-naked-and-afraid-podcast-oh-heck-naa/id1637024575"
        ]},
      { name: "Jaked and Afraid",
        urls: [
          "https://open.spotify.com/show/1jl5pP0rmBlo5Ra2G3sDmQ",
          "https://podcasts.apple.com/us/podcast/jaked-and-afraid/id1673801964"
        ]}
    ]

    books = [
      { name: "The Superwoman's Survival Guide", url: "https://a.co/d/dJEVpqL" },
      { name: "Survive: The All-In-One Guide to Staying Alive in Extreme Conditions", url: "https://a.co/d/aCuVK7B" },
      { name: "When the Grid Fails: Easy Action Steps When Facing Hurricanes, ...", url: "https://a.co/d/cWj7nxr" },
      { name: "Surviving the First 36 Hours", url: "https://a.co/d/bTTnKoz" },
      { name: "Fire: The Complete Guide for Home, Hearth, Camping and Wilderness Survival", url: "https://a.co/d/bTTnKoz" },
      { name: "Adventure Awaits: The Beginner's Guide to the Great Outdoors", url: "https://a.co/d/iNGF8CS" },
      { name: "Girl's Own Survival Guide - Signed Copy", url: "https://kyfurneaux.com/product/girls-own-survival-guide-signed/" }
    ]

    JSON.generate({
      podcasts: podcasts,
      books: books,
      author: { name: "Ky Furneaux" }
    })
  end

  def about_json_payload(name:, description:)
    JSON.generate({
      name: name.to_s,
      description: description.to_s
    })
  end

  # ===== Server-side JSON-LD =====
  # The methods below return full Schema.org hashes/arrays and are rendered as
  # <script type="application/ld+json"> inline in the page so SEO validators
  # and lightweight crawlers (which do not execute JS) can see them.
  #
  # render_jsonld(schema) safely emits the script tag and escapes the unsafe
  # "</" sequence so the JSON cannot break out of the script element.

  def render_jsonld(schema)
    return "" if schema.nil?
    json = JSON.generate(schema).gsub("</", "<\\/")
    content_tag(:script, raw(json), type: "application/ld+json")
  end

  SITE_NAME = "Naked & Afraid Fan Database".freeze

  # Small helper: takes [{name:, path:}] pairs and returns a BreadcrumbList
  # schema. The last item is treated as the current page and gets no URL
  # (per Google's BreadcrumbList guidance).
  def breadcrumb_jsonld(items)
    entries = Array(items).each_with_index.map do |item, i|
      last = (i == items.length - 1)
      entry = { "@type" => "ListItem", "position" => i + 1, "name" => item[:name] }
      entry["item"] = "#{request.base_url}#{item[:path]}" unless last
      entry
    end
    { "@context" => "https://schema.org", "@type" => "BreadcrumbList", "itemListElement" => entries }
  end

  # Shared Author entity for Article schemas — E-A-T signal that says the
  # site's editorial content has a named human behind it.
  def site_author_entity
    { "@type" => "Person", "name" => "Brad Said", "url" => "#{request.base_url}#{about_path}" }
  end

  def home_jsonld
    [
      { "@context" => "https://schema.org", "@type" => "WebSite",
        "name" => SITE_NAME, "url" => request.base_url },
      { "@context" => "https://schema.org", "@type" => "CollectionPage",
        "name" => SITE_NAME,
        "description" => "Fan-maintained guide to episodes, survivors, items, and locations.",
        "url" => request.original_url, "image" => "/favicon.png" }
    ]
  end

  def episode_show_jsonld(episode)
    series_name  = episode.season&.series&.name
    season_num   = episode.season&.number
    ep_num       = episode.number_in_season
    air_iso      = episode.air_date&.to_date&.to_s
    loc          = episode.location
    location_str = [loc&.country, loc&.region, loc&.site].compact_blank.join(", ").presence

    actors = Array(episode.survivors).map { |s| { "@type" => "Person", "name" => s.full_name, "url" => survivor_path(s) } }

    image_url = (episode.appearances.map(&:survivor).find { |s| s&.avatar&.attached? } &&
                 (rails_blob_path(episode.appearances.map(&:survivor).find { |s| s&.avatar&.attached? }.avatar, only_path: true) rescue nil))

    tv_ep = {
      "@context" => "https://schema.org",
      "@type" => "TVEpisode",
      "name" => (episode.title.presence || "Episode"),
      "episodeNumber" => ep_num,
      "partOfSeason" => { "@type" => "TVSeason", "seasonNumber" => season_num,
                          "name" => "#{series_name} Season #{season_num}" },
      "partOfSeries" => { "@type" => "TVSeries", "name" => series_name },
      "url" => request.original_url,
      "actor" => actors
    }
    tv_ep["datePublished"]    = air_iso if air_iso
    tv_ep["locationCreated"]  = { "@type" => "Place", "name" => location_str } if location_str
    tv_ep["image"]            = image_url if image_url

    breadcrumb = breadcrumb_jsonld([
      { name: "Home",     path: root_path },
      { name: "Episodes", path: episodes_path },
      ({ name: "Season #{season_num}", path: season_path(episode.season) } if episode.season),
      { name: episode.title.presence || "Episode", path: episode_path(episode) }
    ].compact)

    schemas = [tv_ep, breadcrumb]

    synopsis_plain = ActionView::Base.full_sanitizer.sanitize(episode.synopsis.to_s).squish
    if synopsis_plain.present?
      schemas << {
        "@context" => "https://schema.org",
        "@type" => "Article",
        "headline" => (episode.title.presence || "Episode"),
        "articleBody" => synopsis_plain,
        "datePublished" => air_iso,
        "dateModified" => episode.updated_at.to_date.to_s,
        "author" => site_author_entity,
        "publisher" => { "@type" => "Organization", "name" => SITE_NAME, "url" => request.base_url },
        "url" => request.original_url,
        "image" => (image_url || nil)
      }.compact
    end

    faq = episode_faq_jsonld(episode)
    schemas << faq if faq
    schemas
  end

  def episodes_index_jsonld(episodes:, season:, location:, episodes_by_season:, episode_counts:)
    if location.present?
      loc_name = [location.site, location.region, location.country].compact_blank.join(", ").presence || "Unknown Location"
      name     = "Episodes in #{loc_name}"
      desc     = "Episodes filmed in #{loc_name}."
      list     = Array(episodes)
    elsif season.present?
      series_name = season.series&.name || "Naked and Afraid"
      title_txt   = "#{series_name} – Season #{season.number}"
      name        = "#{title_txt} Episodes"
      desc        = "Episodes for #{title_txt}."
      list        = Array(episodes)
    else
      name = "Naked and Afraid Episodes"
      desc = "Episode guide organized by season."
      list = (episodes_by_season || {}).values.flatten
    end

    items = list.first(20).each_with_index.map do |ep, i|
      props = [
        ep.season&.series&.name && { "@type" => "PropertyValue", "name" => "Series",   "value" => ep.season.series.name },
        ep.season&.number       && { "@type" => "PropertyValue", "name" => "Season",   "value" => ep.season.number },
        ep.number_in_season     && { "@type" => "PropertyValue", "name" => "Episode",  "value" => ep.number_in_season },
        ep.air_date             && { "@type" => "PropertyValue", "name" => "Air Date", "value" => ep.air_date.strftime("%Y-%m-%d") }
      ].compact
      {
        "@type"    => "ListItem",
        "position" => i + 1,
        "url"      => "#{request.base_url}#{episode_path(ep)}",
        "name"     => (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        "additionalProperty" => props
      }
    end

    {
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => name,
      "description" => desc,
      "numberOfItems" => list.size,
      "itemListElement" => items
    }
  end

  def episodes_by_country_jsonld(country:, episodes:)
    items = Array(episodes).first(20).each_with_index.map do |ep, i|
      props = [
        ep.season&.series&.name && { "@type" => "PropertyValue", "name" => "Series",   "value" => ep.season.series.name },
        ep.season&.number       && { "@type" => "PropertyValue", "name" => "Season",   "value" => ep.season.number },
        ep.number_in_season     && { "@type" => "PropertyValue", "name" => "Episode",  "value" => ep.number_in_season },
        ep.air_date             && { "@type" => "PropertyValue", "name" => "Air Date", "value" => ep.air_date.strftime("%Y-%m-%d") }
      ].compact
      {
        "@type" => "ListItem", "position" => i + 1,
        "url"   => "#{request.base_url}#{episode_path(ep)}",
        "name"  => (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        "additionalProperty" => props
      }
    end
    [
      { "@context" => "https://schema.org", "@type" => "CollectionPage",
        "name" => "Naked and Afraid Episodes in #{country}",
        "url"  => request.original_url,
        "about" => { "@type" => "Place", "name" => country } },
      { "@context" => "https://schema.org", "@type" => "ItemList",
        "name" => "Episodes in #{country}", "numberOfItems" => Array(episodes).size,
        "itemListElement" => items }
    ]
  end

  def items_index_jsonld
    {
      "@context" => "https://schema.org", "@type" => "CollectionPage",
      "name" => "Naked and Afraid Items",
      "description" => "Database of survival items used in Naked and Afraid, including brought, given, and rare items by type and country.",
      "url" => request.original_url
    }
  end

  def item_show_jsonld(item:, given_ai:, brought_ai:, country:)
    given_ep_ids   = Array(given_ai).map { |ai| ai.appearance&.episode_id }.compact.uniq
    brought_ep_ids = Array(brought_ai).map { |ai| ai.appearance&.episode_id }.compact.uniq
    total_ids      = (given_ep_ids + brought_ep_ids).uniq

    episodes = ((Array(given_ai) + Array(brought_ai)).map { |ai| ai.appearance&.episode }.compact.uniq).first(10)
    subject_of = episodes.map do |ep|
      {
        "@type" => "TVEpisode",
        "name"  => (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        "url"   => "#{request.base_url}#{episode_path(ep)}",
        "partOfSeries" => { "@type" => "TVSeries", "name" => ep.season&.series&.name },
        "seasonNumber" => ep.season&.number,
        "episodeNumber" => ep.number_in_season
      }
    end

    props = [
      { "@type" => "PropertyValue", "name" => "Given in episodes",   "value" => given_ep_ids.size },
      { "@type" => "PropertyValue", "name" => "Brought in episodes", "value" => brought_ep_ids.size },
      { "@type" => "PropertyValue", "name" => "Total appearances",   "value" => total_ids.size }
    ]
    props << { "@type" => "PropertyValue", "name" => "Filtered country", "value" => country } if country.present?

    product = {
      "@context" => "https://schema.org", "@type" => "Product",
      "name" => item.name.to_s,
      "category" => (item.respond_to?(:item_type) ? item.item_type : nil),
      "url" => request.original_url,
      "description" => "#{item.name} appearances across Naked and Afraid episodes.",
      "additionalProperty" => props,
      "subjectOf" => subject_of
    }
    breadcrumb = breadcrumb_jsonld([
      { name: "Home",  path: root_path },
      { name: "Items", path: items_path },
      { name: item.name.to_s, path: item_path(item) }
    ])
    [product, breadcrumb]
  end

  def item_type_jsonld(item_type:, country:, items_in_type_count:, given_episode_ids:, brought_episode_ids:, given_ai:, brought_ai:)
    items = ((Array(given_ai) + Array(brought_ai)).map(&:item).compact.uniq).first(10).each_with_index.map do |it, i|
      { "@type" => "ListItem", "position" => i + 1,
        "url" => "#{request.base_url}#{item_path(it)}", "name" => it.name }
    end
    name = "#{item_type} Items#{country.present? ? " in #{country}" : ""}"
    {
      "@context" => "https://schema.org", "@type" => "ItemList",
      "name" => name,
      "numberOfItems" => items_in_type_count.to_i,
      "description" => "Given in #{Array(given_episode_ids).uniq.size} episode(s), brought in #{Array(brought_episode_ids).uniq.size}.",
      "itemListElement" => items
    }
  end

  def locations_index_jsonld(countries_count_hash)
    countries = (countries_count_hash || {}).map do |name, total|
      { "@type" => "Place", "name" => name, "description" => "#{total} episodes filmed" }
    end
    {
      "@context" => "https://schema.org", "@type" => "CollectionPage",
      "name" => "Naked and Afraid Locations",
      "description" => "Map and country breakdown of filming locations across all episodes.",
      "url" => request.original_url, "hasPart" => countries
    }
  end

  def seasons_index_jsonld(seasons:)
    seasons = Array(seasons)
    items = seasons.first(20).each_with_index.map do |s, i|
      props = [
        s.series&.name && { "@type" => "PropertyValue", "name" => "Series",   "value" => s.series.name },
        s.number       && { "@type" => "PropertyValue", "name" => "Season",   "value" => s.number },
        s.respond_to?(:episodes) && { "@type" => "PropertyValue", "name" => "Episodes", "value" => s.episodes.size }
      ].select { |p| p.is_a?(Hash) }
      { "@type" => "ListItem", "position" => i + 1,
        "url" => "#{request.base_url}#{season_path(s)}",
        "name" => "#{s.series&.name} – Season #{s.number}",
        "additionalProperty" => props }
    end
    {
      "@context" => "https://schema.org", "@type" => "ItemList",
      "name" => "Naked and Afraid Seasons",
      "numberOfItems" => seasons.size,
      "itemListElement" => items
    }
  end

  def season_show_jsonld(season:, episodes:)
    eps_list = Array(episodes).first(20)
    list_items = eps_list.each_with_index.map do |ep, i|
      props = [
        ep.season&.number    && { "@type" => "PropertyValue", "name" => "Season",   "value" => ep.season.number },
        ep.number_in_season  && { "@type" => "PropertyValue", "name" => "Episode",  "value" => ep.number_in_season },
        ep.air_date          && { "@type" => "PropertyValue", "name" => "Air date", "value" => ep.air_date.strftime("%Y-%m-%d") }
      ].compact
      { "@type" => "ListItem", "position" => i + 1,
        "url" => "#{request.base_url}#{episode_path(ep)}",
        "name" => (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        "additionalProperty" => props }
    end
    label = "#{season.series&.name} – Season #{season.number}"
    first_air = eps_list.map(&:air_date).compact.min&.to_s
    last_air  = eps_list.map(&:air_date).compact.max&.to_s
    schemas = [
      {
        "@context" => "https://schema.org", "@type" => "TVSeason",
        "name" => label, "seasonNumber" => season.number,
        "partOfSeries" => { "@type" => "TVSeries", "name" => season.series&.name },
        "numberOfEpisodes" => Array(episodes).size,
        "url" => request.original_url
      }.tap { |h| h["startDate"] = first_air if first_air; h["endDate"] = last_air if last_air }
    ]
    if list_items.any?
      schemas << { "@context" => "https://schema.org", "@type" => "ItemList",
                   "name" => "#{label} — Episodes", "itemListElement" => list_items }
    end
    schemas << breadcrumb_jsonld([
      { name: "Home",    path: root_path },
      { name: "Seasons", path: seasons_path },
      { name: label,     path: season_path(season) }
    ])

    intro_plain = ActionView::Base.full_sanitizer.sanitize(season.intro.to_s).squish
    if intro_plain.present?
      schemas << {
        "@context" => "https://schema.org",
        "@type" => "Article",
        "headline" => "#{label} — Season Overview",
        "articleBody" => intro_plain,
        "datePublished" => (first_air || season.created_at.to_date.to_s),
        "dateModified" => season.updated_at.to_date.to_s,
        "author" => site_author_entity,
        "publisher" => { "@type" => "Organization", "name" => SITE_NAME, "url" => request.base_url },
        "url" => request.original_url
      }
    end
    schemas
  end

  def survivors_index_jsonld(top_survivors:, survivors:)
    list = (Array(top_survivors).presence || Array(survivors)).first(20)
    items = list.each_with_index.map do |s, i|
      total     = s.respond_to?(:episodes_total_count)     ? s.episodes_total_count.to_i     : s.appearances.select(:episode_id).distinct.count
      collapsed = s.respond_to?(:episodes_collapsed_count) ? s.episodes_collapsed_count.to_i : total
      img = if s.respond_to?(:avatar) && s.avatar&.attached?
              rails_blob_path(s.avatar, only_path: true) rescue nil
            end
      person = {
        "@type" => "Person",
        "name"  => s.try(:full_name) || s.try(:name) || "Survivor ##{s.id}",
        "url"   => "#{request.base_url}#{survivor_path(s)}",
        "additionalProperty" => [
          { "@type" => "PropertyValue", "name" => "Episodes (total)", "value" => total },
          { "@type" => "PropertyValue", "name" => "Challenges",       "value" => collapsed }
        ]
      }
      person["image"] = img if img
      { "@type" => "ListItem", "position" => i + 1,
        "url" => person["url"], "name" => person["name"], "item" => person }
    end
    {
      "@context" => "https://schema.org", "@type" => "ItemList",
      "name" => "Naked and Afraid Survivors",
      "numberOfItems" => list.size,
      "itemListElement" => items
    }
  end

  def survivor_show_jsonld(survivor:, appearances:)
    img = if survivor.respond_to?(:avatar) && survivor.avatar&.attached?
            rails_blob_path(survivor.avatar, only_path: true) rescue nil
          end
    same_as = []
    if survivor.respond_to?(:instagram) && survivor.instagram.present?
      handle = survivor.instagram.to_s.strip.sub(/\A@/, '').sub(%r{\Ahttps?://(www\.)?instagram\.com/}i, '').sub(%r{/.*$}, '')
      same_as << "https://www.instagram.com/#{handle}" unless handle.empty?
    end
    if survivor.respond_to?(:facebook) && survivor.facebook.present?
      handle = survivor.facebook.to_s.strip.sub(/\A@/, '').sub(%r{\Ahttps?://(www\.)?facebook\.com/}i, '').sub(%r{/.*$}, '')
      same_as << "https://www.facebook.com/#{handle}" unless handle.empty?
    end

    episodes_total = survivor.appearances.select(:episode_id).distinct.count
    challenges     = survivor.respond_to?(:episodes_collapsed_count) ? survivor.episodes_collapsed_count.to_i : episodes_total

    person = {
      "@context" => "https://schema.org", "@type" => "Person",
      "name" => survivor.full_name.to_s, "url" => request.original_url,
      "description" => "#{survivor.full_name} from Naked and Afraid with #{episodes_total} episode(s) and #{challenges} challenge(s)."
    }
    person["image"]  = img if img
    person["sameAs"] = same_as if same_as.any?

    breadcrumb = breadcrumb_jsonld([
      { name: "Home",      path: root_path },
      { name: "Survivors", path: survivors_path },
      { name: survivor.full_name.to_s, path: survivor_path(survivor) }
    ])

    schemas = [person, breadcrumb]

    bio_plain = ActionView::Base.full_sanitizer.sanitize(survivor.bio.to_s).squish
    if bio_plain.present?
      schemas << {
        "@context" => "https://schema.org",
        "@type" => "Article",
        "headline" => "#{survivor.full_name} — Naked and Afraid Survivor",
        "articleBody" => bio_plain,
        "datePublished" => survivor.created_at.to_date.to_s,
        "dateModified" => survivor.updated_at.to_date.to_s,
        "author" => site_author_entity,
        "publisher" => { "@type" => "Organization", "name" => SITE_NAME, "url" => request.base_url },
        "url" => request.original_url,
        "image" => img
      }.compact
    end

    faq = survivor_faq_jsonld(survivor)
    schemas << faq if faq
    schemas
  end

  def podcasts_books_jsonld
    podcasts = [
      { name: "Oh Heck NAA - A Naked and Afraid Podcast",
        urls: ["https://open.spotify.com/show/2q2ZfSDQiL6u26dV4o2fNN",
               "https://podcasts.apple.com/us/podcast/a-naked-and-afraid-podcast-oh-heck-naa/id1637024575"] },
      { name: "Jaked and Afraid",
        urls: ["https://open.spotify.com/show/1jl5pP0rmBlo5Ra2G3sDmQ",
               "https://podcasts.apple.com/us/podcast/jaked-and-afraid/id1673801964"] }
    ]
    books = [
      { name: "The Superwoman's Survival Guide", url: "https://a.co/d/dJEVpqL" },
      { name: "Survive: The All-In-One Guide to Staying Alive in Extreme Conditions", url: "https://a.co/d/aCuVK7B" },
      { name: "When the Grid Fails: Easy Action Steps When Facing Hurricanes", url: "https://a.co/d/cWj7nxr" },
      { name: "Surviving the First 36 Hours", url: "https://a.co/d/bTTnKoz" },
      { name: "Fire: The Complete Guide for Home, Hearth, Camping and Wilderness Survival", url: "https://a.co/d/bTTnKoz" },
      { name: "Adventure Awaits: The Beginner's Guide to the Great Outdoors", url: "https://a.co/d/iNGF8CS" },
      { name: "Girl's Own Survival Guide - Signed Copy", url: "https://kyfurneaux.com/product/girls-own-survival-guide-signed/" }
    ]
    author = { "@type" => "Person", "name" => "Ky Furneaux" }
    [
      { "@context" => "https://schema.org", "@type" => "CollectionPage",
        "name" => "Naked & Afraid Podcasts and Books",
        "url"  => request.original_url,
        "description" => "Fan podcasts about Naked & Afraid and recommended books by Ky Furneaux." },
      { "@context" => "https://schema.org", "@type" => "ItemList",
        "name" => "Naked & Afraid Podcasts",
        "itemListElement" => podcasts.each_with_index.map { |p, i|
          { "@type" => "ListItem", "position" => i + 1,
            "item" => { "@type" => "PodcastSeries", "name" => p[:name], "sameAs" => p[:urls] } } } },
      { "@context" => "https://schema.org", "@type" => "ItemList",
        "name" => "Books by Ky Furneaux",
        "itemListElement" => books.each_with_index.map { |b, i|
          item = { "@type" => "Book", "name" => b[:name], "author" => author }
          item["offers"] = { "@type" => "Offer", "url" => b[:url] } if b[:url]
          { "@type" => "ListItem", "position" => i + 1, "item" => item } } }
    ]
  end

  # Returns an Array of {q:, a:} pairs dynamically derived from the survivor's
  # appearance record. Consumed both by survivor_faq_jsonld (for schema.org)
  # and by the view, since Google requires FAQ answers to be visible on-page.
  def survivor_faq_qas(survivor)
    name = survivor.full_name.to_s
    apps = survivor.appearances.includes(episode: :season).to_a
    qas  = []

    seasons = apps.map { |a| a.episode&.season }.compact.uniq
    if seasons.any?
      season_labels = seasons.map { |s| "#{s.series&.name} Season #{s.number}" }.uniq
      qas << { q: "Which Naked and Afraid seasons has #{name} appeared in?",
               a: "#{name} has appeared in #{season_labels.to_sentence}." }
    end

    ep_count = apps.map(&:episode_id).compact.uniq.size
    if ep_count.positive?
      qas << { q: "How many episodes of Naked and Afraid has #{name} been in?",
               a: "#{name} has appeared in #{ep_count} episode#{'s' if ep_count != 1} of Naked and Afraid." }
    end

    psrs = apps.map(&:ending_psr).compact
    if psrs.any?
      best = psrs.max
      best_str = (best % 1).zero? ? best.to_i.to_s : format("%.1f", best)
      qas << { q: "What is #{name}'s highest PSR rating on Naked and Afraid?",
               a: "#{name}'s highest recorded PSR rating is #{best_str}." }
    end

    completed = apps.count { |a| a.result.to_s.match?(/complete|success/i) }
    tapped    = apps.count { |a| a.result.to_s.match?(/tap|medical|evac|out/i) }
    if (completed + tapped).positive?
      total = ep_count
      qas << {
        q: "Has #{name} completed a Naked and Afraid challenge?",
        a: if completed.positive?
             "Yes — #{name} has completed at least #{completed} challenge#{'s' if completed != 1} across their #{total} episode appearance#{'s' if total != 1}."
           else
             "Across #{total} appearance#{'s' if total != 1}, #{name} has tapped or been medically evacuated in each challenge on record."
           end
      }
    end

    qas
  end

  # Assembles a FAQPage schema from dynamically-derived Q&As about a survivor.
  # Google reduced FAQ rich-result surfacing in 2023, but the schema remains
  # valid and gives crawlers stronger semantic hints about the page content.
  def survivor_faq_jsonld(survivor)
    qas = survivor_faq_qas(survivor)
    return nil if qas.empty?
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => qas.map { |qa|
        { "@type" => "Question",
          "name" => qa[:q],
          "acceptedAnswer" => { "@type" => "Answer", "text" => qa[:a] } }
      }
    }
  end

  # Q&A pairs for an episode — location, air date, cast, and season context.
  def episode_faq_qas(episode)
    ep_label = episode.title.presence || "Episode #{episode.number_in_season || episode.id}"
    loc      = episode.location
    location_str = [loc&.site, loc&.region, loc&.country].compact_blank.join(", ").presence
    series_name  = episode.season&.series&.name
    season_num   = episode.season&.number
    qas = []

    if location_str
      qas << { q: "Where was #{ep_label} filmed?",
               a: "#{ep_label} was filmed in #{location_str}." }
    end

    if episode.air_date
      qas << { q: "When did #{ep_label} air?",
               a: "#{ep_label} originally aired on #{episode.air_date.strftime('%B %-d, %Y')}." }
    end

    survivors = Array(episode.survivors)
    if survivors.any?
      names = survivors.map(&:full_name).to_sentence
      qas << { q: "Who appeared in #{ep_label}?",
               a: "The survivalists in #{ep_label} were #{names}." }
    end

    if series_name && season_num
      qas << { q: "What season of Naked and Afraid is #{ep_label} from?",
               a: "#{ep_label} is from #{series_name} Season #{season_num}." }
    end

    qas
  end

  # FAQPage schema for an episode.
  def episode_faq_jsonld(episode)
    qas = episode_faq_qas(episode)
    return nil if qas.empty?
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => qas.map { |qa|
        { "@type" => "Question",
          "name" => qa[:q],
          "acceptedAnswer" => { "@type" => "Answer", "text" => qa[:a] } }
      }
    }
  end

  def about_jsonld(name:, description:)
    {
      "@context" => "https://schema.org", "@type" => "AboutPage",
      "name" => name.to_s, "description" => description.to_s,
      "url" => request.original_url
    }
  end
end
