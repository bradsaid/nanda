require "test_helper"

class EpisodeTest < ActiveSupport::TestCase
  # Every participant_arrangement seen in production, and how many teams it means.
  PRODUCTION_ARRANGEMENTS = {
    nil => 1, "" => 1, "Standard" => 1, "Group" => 1, "Trio" => 1, "Solo" => 1,
    "3" => 1, "4" => 1,
    "2+2" => 2, "3+2" => 2, "3+3+3" => 3, "3+3+3+2" => 4, "3+3+3+3" => 4,
    "3+3+3+3+1" => 5, "2+2+2+2+2+2+2" => 7, "2+3+3+3+3" => 5
  }.freeze

  test "team_count_for reads the number of teams from every production arrangement" do
    PRODUCTION_ARRANGEMENTS.each do |arrangement, teams|
      assert_equal teams, Episode.team_count_for(arrangement), "arrangement #{arrangement.inspect}"
    end
  end

  test "team_count_for ignores spaces, empty parts and anything that is not a positive whole number" do
    assert_equal 2, Episode.team_count_for(" 3 + 2 ")
    assert_equal 2, Episode.team_count_for("3+2+")
    assert_equal 1, Episode.team_count_for("+")
    assert_equal 1, Episode.team_count_for("0")
    assert_equal 2, Episode.team_count_for("3+0+2")
    assert_equal 2, Episode.team_count_for("3+x+2")
    assert_equal 1, Episode.team_count_for("three")
    assert_equal 1, Episode.team_count_for("2.5")
    assert_equal 1, Episode.team_count_for("-3")
  end

  test "Episode#team_count and multi_team? use the episode's arrangement" do
    ep = Episode.new(participant_arrangement: "3+3+3+3")
    assert_equal 4, ep.team_count
    assert ep.multi_team?
    ep.participant_arrangement = "Standard"
    assert_equal 1, ep.team_count
    assert_not ep.multi_team?
    assert_equal 1, Episode.new.team_count
  end

  test "team_count_known? is false only when the arrangement says nothing about teams" do
    %w[Standard Trio Solo 3 4 2+2 3+3+3+3].each { |a| assert Episode.new(participant_arrangement: a).team_count_known?, a }
    [nil, "", "Group", "Tribes of Eight"].each { |a| assert_not Episode.new(participant_arrangement: a).team_count_known?, a.inspect }
  end

  test "the SQL team count agrees with the Ruby one for every arrangement" do
    tricky = [" 3 + 2 ", "3+2+", "+", "0", "3+0+2", "3+x+2", "three", "2.5", "-3", "99999999999999999999+1"]
    (PRODUCTION_ARRANGEMENTS.keys + tricky).each do |arrangement|
      ep, = build_episode_with_survivors(1, arrangement: arrangement)
      sql = Episode.where(id: ep.id).pick(Arel.sql(Episode.team_count_sql("episodes")))
      assert_equal Episode.team_count_for(arrangement), sql, "arrangement #{arrangement.inspect}"
    end
  end
end
