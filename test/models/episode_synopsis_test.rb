require "test_helper"

# What counts as "has a synopsis" (Episode#synopsis_present?, the without_synopsis / with_synopsis
# scopes) and the ThinContent switch built on it. The Ruby rule and the SQL rule must agree:
# the admin synopsis queue and the sitemap use the scopes, the page's robots tag uses the method.
class EpisodeSynopsisTest < ActiveSupport::TestCase
  BLANKS  = [ nil, "", "   ", "\n\t ", "<p></p>", "<p>&nbsp;</p>", " &nbsp; ", "<br>", "\u00a0" ].freeze
  PRESENT = [ "A real synopsis.", "<p>Two survivalists.</p>", "  padded text  ", "In the wilds of Zambia" ].freeze

  def episode_with(synopsis)
    n = (@n = @n.to_i + 1) + 5000
    Episode.create!(season: seasons(:one), location: locations(:one), title: "Syn #{n}", number_in_season: n, synopsis: synopsis)
  end

  test "blank, whitespace-only and markup-only synopses are missing; real text is present" do
    BLANKS.each  { |v| assert_not episode_with(v).synopsis_present?, "#{v.inspect} should count as no synopsis" }
    PRESENT.each { |v| assert episode_with(v).synopsis_present?, "#{v.inspect} should count as a synopsis" }
  end

  test "the SQL scopes agree with the Ruby rule" do
    episodes = (BLANKS + PRESENT).map { |v| episode_with(v) }
    missing  = Episode.without_synopsis.where(id: episodes.map(&:id)).pluck(:id).sort
    present  = Episode.with_synopsis.where(id: episodes.map(&:id)).pluck(:id).sort
    assert_equal episodes.reject(&:synopsis_present?).map(&:id).sort, missing
    assert_equal episodes.select(&:synopsis_present?).map(&:id).sort, present
  end

  test "synopsis_text is plain text with entities decoded and whitespace squished" do
    assert_equal "Fish & chips for two.", episode_with("<p>Fish &amp;   chips\nfor two.</p>").synopsis_text
    assert_equal "", episode_with(nil).synopsis_text
  end

  test "thin? follows NOINDEX_THIN_EPISODES" do
    bare = episode_with(nil)
    full = episode_with("Something happens.")
    assert bare.thin?
    assert_not full.thin?
    with_env("NOINDEX_THIN_EPISODES" => "false") do
      assert_not bare.thin?
      assert_equal Episode.count, Episode.indexable.count
    end
    assert_equal Episode.with_synopsis.count, Episode.indexable.count
  end

  test "ThinContent flags and thresholds, with safe fallbacks for bad values" do
    assert ThinContent.noindex_episodes_without_synopsis?
    %w[false FALSE 0 no off].each do |v|
      with_env("NOINDEX_THIN_EPISODES" => v) { assert_not ThinContent.noindex_episodes_without_synopsis?, v }
    end
    assert_equal 2, ThinContent.food_source_min_episodes
    assert ThinContent.thin_food_source?(1)
    assert_not ThinContent.thin_food_source?(2)
    with_env("THIN_FOOD_SOURCE_MIN_EPISODES" => "5") { assert ThinContent.thin_food_source?(4) }
    with_env("THIN_FOOD_SOURCE_MIN_EPISODES" => "0") { assert_not ThinContent.thin_food_source?(0) }
    with_env("THIN_SHELTER_MIN_EPISODES" => "junk") { assert_equal 2, ThinContent.shelter_min_episodes }
  end

  def with_env(vars)
    old = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end
