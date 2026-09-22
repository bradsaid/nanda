require "test_helper"

class Forum::MentionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @survivor = survivors(:one)
    @episode  = episodes(:one)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def results_for(**params)
    get forum_mentions_path, params: params
    assert_response :success
    JSON.parse(@response.body).fetch("results")
  end

  test "a survivor is found by the squashed name people actually type" do
    name = @survivor.full_name
    squashed = name.downcase.gsub(/[^a-z0-9]/, "")
    found = results_for(type: "survivor", q: squashed)
    assert_includes found.map { |r| r["label"] }, name,
      "typing the name without spaces must still match"
    assert_equal survivor_path(@survivor), found.first["path"]
  end

  test "a partial name matches" do
    found = results_for(type: "survivor", q: @survivor.full_name[0, 3].downcase)
    assert_includes found.map { |r| r["label"] }, @survivor.full_name
  end

  test "episodes are searchable by title" do
    found = results_for(type: "episode", q: @episode.title[0, 4])
    assert found.any? { |r| r["path"] == episode_path(@episode) }
  end

  test "episodes are searchable by season-and-number shorthand" do
    found = results_for(type: "episode", q: "s#{@episode.season.number}e#{@episode.number_in_season}")
    assert_equal episode_path(@episode), found.first["path"]
    assert_match(/\AS\d+E\d+ /, found.first["label"])
  end

  test "an empty query returns nothing rather than the whole table" do
    assert_empty results_for(type: "survivor", q: "")
    assert_empty results_for(type: "survivor", q: "   ")
  end

  test "no match returns an empty list, not an error" do
    assert_empty results_for(type: "survivor", q: "zzzznobodyzzz")
  end

  test "the endpoint is hidden while the forum is closed" do
    ENV["FORUM_ENABLED"] = nil
    get forum_mentions_path, params: { type: "survivor", q: "a" }
    assert_response :not_found
  end
end
