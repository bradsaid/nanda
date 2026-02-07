# app/services/new_season_helper.rb
# Console helper for adding new season data.
#
# Usage (from `rails console`):
#
#   season = NewSeasonHelper.add_season(series_name: "Naked and Afraid", number: 18, year: 2026)
#
#   ep = NewSeasonHelper.add_episode(season: season, number: 1, title: "Into the Wild",
#                                    country: "Colombia", scheduled_days: 21)
#
#   s = NewSeasonHelper.add_survivor(full_name: "Jane Doe",
#                                    avatar_url: "https://example.com/jane.jpg",
#                                    instagram: "janedoe")
#
#   NewSeasonHelper.add_appearance(survivor: s, episode: ep, role: "duo",
#                                  brought_item: "machete", given_items: ["fire starter"])
#
require "open-uri"

class NewSeasonHelper
  class << self
    def add_season(series_name:, number:, year:, continuous_story: false)
      series = Series.find_or_create_by!(name: series_name)
      season = Season.find_or_create_by!(series: series, number: number) do |s|
        s.year = year
        s.continuous_story = continuous_story
      end
      season.update!(year: year, continuous_story: continuous_story)
      puts "Season #{number} (#{year}) — #{series.name} [id=#{season.id}]"
      season
    end

    def add_episode(season:, number:, title:, country:, air_date: nil, scheduled_days: nil,
                    participant_arrangement: nil, type_modifiers: nil, region: nil, site: nil, notes: nil)
      location = Location.find_or_create_by!(country: country, region: region, site: site)

      episode = Episode.find_or_create_by!(season: season, number_in_season: number) do |e|
        e.title = title
        e.air_date = air_date
        e.scheduled_days = scheduled_days
        e.participant_arrangement = participant_arrangement
        e.type_modifiers = type_modifiers
        e.location = location
        e.notes = notes
      end
      puts "Episode #{number}: \"#{episode.title}\" — #{location.country} [id=#{episode.id}]"
      episode
    end

    def add_survivor(full_name:, avatar_url: nil, instagram: nil, facebook: nil,
                     youtube: nil, website: nil, onlyfans: nil, cameo: nil, merch: nil, other: nil)
      survivor = Survivor.find_or_create_by!(full_name: full_name)

      attrs = { instagram: instagram, facebook: facebook, youtube: youtube,
                website: website, onlyfans: onlyfans, cameo: cameo,
                merch: merch, other: other }.compact
      survivor.update!(attrs) if attrs.any?

      if avatar_url.present?
        attach_avatar(survivor, avatar_url)
      end

      puts "Survivor: #{survivor.full_name} [id=#{survivor.id}] avatar=#{survivor.avatar.attached?}"
      survivor
    end

    def add_appearance(survivor:, episode:, role: "duo", brought_item: nil, given_items: [],
                       starting_psr: nil, ending_psr: nil, days_lasted: nil, result: nil, notes: nil)
      appearance = Appearance.find_or_create_by!(survivor: survivor, episode: episode) do |a|
        a.role = role
        a.starting_psr = starting_psr
        a.ending_psr = ending_psr
        a.days_lasted = days_lasted
        a.result = result
        a.notes = notes
      end

      if brought_item.present?
        item = Item.find_or_create_by!(name: brought_item.strip.downcase)
        AppearanceItem.find_or_create_by!(appearance: appearance, item: item, source: "brought")
        puts "  Brought: #{item.name} (#{item.item_type})"
      end

      Array(given_items).each do |name|
        item = Item.find_or_create_by!(name: name.strip.downcase)
        AppearanceItem.find_or_create_by!(appearance: appearance, item: item, source: "given")
        puts "  Given: #{item.name} (#{item.item_type})"
      end

      puts "Appearance: #{survivor.full_name} in E#{episode.number_in_season} " \
           "[role=#{appearance.role}] [id=#{appearance.id}]"
      appearance
    end

    private

    def attach_avatar(survivor, url)
      io = URI.open(url)
      filename = File.basename(URI.parse(url).path)
      filename = "avatar.jpg" if filename.blank? || !filename.include?(".")
      content_type = io.content_type rescue "image/jpeg"

      survivor.avatar.attach(
        io: io,
        filename: filename,
        content_type: content_type
      )
      puts "  Avatar attached from #{url}"
    rescue => e
      puts "  WARNING: Avatar download failed — #{e.message}"
    end
  end
end
