ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    # An episode with `survivors` survivors on it, for tests that count given/brought
    # items. Returns [episode, appearances].
    def build_episode_with_survivors(survivors, title: "Counting Ep #{SecureRandom.hex(3)}", season: nil, location: nil, arrangement: nil)
      season   ||= seasons(:one)
      location ||= locations(:one)
      episode = Episode.create!(season: season, location: location, title: title, number_in_season: rand(1000..99_999),
                                air_date: Date.new(2024, 1, 1) + rand(1..3000), participant_arrangement: arrangement)
      appearances = Array.new(survivors) do |i|
        Appearance.create!(episode: episode, survivor: Survivor.create!(full_name: "#{title} Survivor #{i + 1}"))
      end
      [episode, appearances]
    end

    # One given row per appearance, the way the app stores "given to the team".
    def give(item, appearances, scope: "team", quantity: 1, subtype: nil)
      Array(appearances).map do |a|
        AppearanceItem.create!(appearance: a, item: item, source: "given", given_scope: scope, quantity: quantity, subtype: subtype)
      end
    end
  end
end
