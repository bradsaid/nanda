# app/helpers/json_ld_helper.rb
module JsonLdHelper
  # Returns a JSON string for episodes index schema module to consume
  # Usage from view:
  #   episodes_index_json_payload(location: @location, episodes: @episodes, season: @season, episodes_by_season: @episodes_by_season, episode_counts: @episode_counts)
  def episodes_index_json_payload(location:, episodes:, season:, episodes_by_season:, episode_counts:)
    simplify = ->(ep) {
      {
        name:   (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        url:    episode_url(ep),
        series: ep.season&.series&.name,
        season: ep.season&.number,
        number: ep.number_in_season,
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
    actors       = Array(episode.survivors).map { |s| { name: s.full_name, url: survivor_url(s) } }

    # If any survivor has an avatar attached, use the first as preview image
    image_url = episode.appearances
                        .map { |a| a.survivor }
                        .find { |s| s&.avatar&.attached? }
                        &.yield_self { |s| Rails.application.routes.url_helpers.url_for(s.avatar) } rescue nil

    JSON.generate({
        title: (episode.title.presence || "Episode"),
        series_name: series_name,
        season_number: season_num,
        episode_number: ep_num,
        air_date_iso: air_iso,
        location: location_str,
        actors: actors,
        image: image_url
    })
  end

    def episodes_by_country_json_payload(country:, episodes:)
        simplify = ->(ep) {
            {
                name:   (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
                url:    episode_url(ep),
                series: ep.season&.series&.name,
                season: ep.season&.number,
                number: ep.number_in_season,
                air_date: ep.air_date&.strftime("%Y-%m-%d"),
                location: [ep.location&.country, ep.location&.region, ep.location&.site].compact_blank.join(", ").presence
            }
        }
        payload = {
            country: country.to_s,
            count: Array(episodes).size,
            episodes: Array(episodes).first(20).map(&simplify)
        }
        JSON.generate(payload)
    end

    def item_show_json_payload(item:, given_ai:, brought_ai:, country:)
        simplify_episode = ->(ep) {
            {
                name:   (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
                url:    episode_url(ep),
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
            name:    item.name.to_s,
            category:(item.respond_to?(:item_type) ? item.item_type : nil),
            given:   given_eps_ids.size,
            brought: brought_eps_ids.size,
            total:   total_ids.size,
            country: country.presence,
            episodes: episodes
        })
  end

  def item_type_json_payload(item_type:, country:, items_in_type_count:, given_episode_ids:, brought_episode_ids:, given_ai:, brought_ai:)
    # Sample up to 10 distinct items shown on the page
    items = ((Array(given_ai) + Array(brought_ai)).map(&:item).compact.uniq)
              .first(10)
              .map { |it| { name: it.name, url: item_url(it) } }

    JSON.generate({
      type: item_type.to_s,
      country: country.presence,
      items_count: items_in_type_count.to_i,
      given: Array(given_episode_ids).uniq.size,
      brought: Array(brought_episode_ids).uniq.size,
      items: items
    })
  end

    # JSON for Seasons index (consumed by json_ld/seasons_index.js)
  def seasons_index_json_payload(seasons:)
    seasons = Array(seasons)
    sample = seasons.first(20).map do |s|
      {
        url:    season_url(s),
        name:   "#{s.series&.name} – Season #{s.number}",
        series: s.series&.name,
        number: s.number,
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
            url:      episode_url(ep),
            number:   ep.number_in_season,
            air_date: ep.air_date&.strftime("%Y-%m-%d"),
            location: [ep.location&.country, ep.location&.region, ep.location&.site].compact_blank.join(", ").presence,
            series:   ep.season&.series&.name
            }
        end

        JSON.generate({
            series_name:    series_name,
            season_number:  season_num,
            episode_count:  Array(episodes).size,
            episodes:       episodes_simplified
        })
    end

    def survivors_index_json_payload(top_survivors:, survivors:)
        list = (Array(top_survivors).presence || Array(survivors)).first(20)

        simplified = list.map do |s|
            total     = s.respond_to?(:episodes_total_count)     ? s.episodes_total_count.to_i     : s.appearances.select(:episode_id).distinct.count
            collapsed = s.respond_to?(:episodes_collapsed_count) ? s.episodes_collapsed_count.to_i : total
            img =
            if s.respond_to?(:avatar) && s.avatar&.attached?
                Rails.application.routes.url_helpers.url_for(s.avatar) rescue nil
            end

            {
                name: s.try(:full_name) || s.try(:name) || "Survivor ##{s.id}",
                url:  Rails.application.routes.url_helpers.survivor_url(s),
                image: img,
                episodes_total: total,
                challenges: collapsed
            }
        end

        JSON.generate({
            count: list.size,
            survivors: simplified
        })
    end

  def survivor_show_json_payload(survivor:, appearances:)
    img =
      if survivor.respond_to?(:avatar) && survivor.avatar&.attached?
        Rails.application.routes.url_helpers.url_for(survivor.avatar) rescue nil
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
        name:   (ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"),
        url:    Rails.application.routes.url_helpers.episode_url(ep),
        series: ep.season&.series&.name,
        season: ep.season&.number,
        number: ep.number_in_season,
        air_date: ep.air_date&.strftime("%Y-%m-%d"),
        location: [ep.location&.country, ep.location&.region, ep.location&.site].compact_blank.join(", ").presence,
        days: a.days_lasted,
        psr: [a.starting_psr, a.ending_psr].compact.join(" → ").presence,
        result: a.result.presence
      }
    end.compact.first(20)

    JSON.generate({
      name: survivor.full_name.to_s,
      url:  Rails.application.routes.url_helpers.survivor_url(survivor),
      image: img,
      sameAs: social,
      episodes_total: survivor.appearances.select(:episode_id).distinct.count,
      challenges: (survivor.respond_to?(:episodes_collapsed_count) ? survivor.episodes_collapsed_count.to_i : nil),
      episodes: eps
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
      author: {
        name: "Ky Furneaux"
      }
    })
  end

  def about_json_payload(name:, description:)
    JSON.generate({
      name: name.to_s,
      description: description.to_s
    })
  end

end
