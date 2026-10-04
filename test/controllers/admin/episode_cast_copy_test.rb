require "test_helper"

# Editing episode 2 of a season whose every episode already exists copied the
# FINALE's roster (the "latest" episode) rather than episode 1's, appended
# people already on the form, and then 500'd on the unique
# (survivor_id, episode_id) index when saved.
class Admin::EpisodeCastCopyTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }

    @series   = Series.create!(name: "Copy Test XL", continuous_story: true)
    @season   = Season.create!(series: @series, number: 1, year: 2020)
    # The fixture, not Location.create!: a new location geocodes itself with
    # a real HTTP call in after_validation, which made this file take nearly a
    # minute and depend on an external API.
    @location = locations(:one)

    @stayer  = Survivor.create!(full_name: "Stays In")
    @tapper  = Survivor.create!(full_name: "Taps Out")
    @joiner  = Survivor.create!(full_name: "Joins Later")

    @e1 = make_episode(1, "One",   Date.new(2020, 5, 24))
    @e2 = make_episode(2, "Two",   Date.new(2020, 5, 31))
    @e3 = make_episode(3, "Three", Date.new(2020, 6, 7))

    @e1.appearances.create!(survivor: @stayer)
    @e1.appearances.create!(survivor: @tapper, result: "tap_out")
    @e2.appearances.create!(survivor: @stayer)
    @e3.appearances.create!(survivor: @stayer)
    @e3.appearances.create!(survivor: @joiner)
  end

  def make_episode(n, title, date)
    Episode.create!(season: @season, number_in_season: n, title: title, air_date: date, location: @location)
  end

  def participants_for(exclude:)
    get latest_episode_participants_admin_season_path(@season, format: :json), params: { exclude_episode_id: exclude.id }
    assert_response :success
    JSON.parse(@response.body)
  end

  test "editing episode 2 copies from episode 1, not from the finale" do
    data = participants_for(exclude: @e2)
    assert_equal @e1.id, data.dig("from_episode", "id"), "must be the immediately preceding episode"
    names = data["participants"].map { |p| p["full_name"] }
    assert_not_includes names, "Joins Later", "someone who only appears later must not be copied backwards"
  end

  test "someone who tapped out is not copied forward" do
    names = participants_for(exclude: @e2)["participants"].map { |p| p["full_name"] }
    assert_includes names, "Stays In"
    assert_not_includes names, "Taps Out"
  end

  test "editing the first episode has nothing to copy from" do
    data = participants_for(exclude: @e1)
    assert_empty data["participants"]
  end

  test "adding a new episode still copies from the latest one" do
    get latest_episode_participants_admin_season_path(@season, format: :json)
    assert_equal @e3.id, JSON.parse(@response.body).dig("from_episode", "id")
  end

  # The 500. A survivor already on the episode submitted again as a new row.
  test "saving a duplicate survivor row does not 500 and keeps one row" do
    existing = @e2.appearances.find_by(survivor: @stayer)
    assert_no_difference "Appearance.count" do
      patch admin_episode_path(@e2), params: { episode: {
        title: "Two",
        appearances_attributes: {
          "0" => { id: existing.id, survivor_id: @stayer.id },
          "1" => { survivor_id: @stayer.id }   # the copy's duplicate
        }
      } }
    end
    assert_response :redirect, "a duplicate must be absorbed, not turned into an error"
    assert_equal 1, @e2.appearances.where(survivor: @stayer).count
  end

  test "two new rows for the same survivor collapse to one" do
    assert_difference "Appearance.count", 1 do
      patch admin_episode_path(@e2), params: { episode: {
        title: "Two",
        appearances_attributes: {
          "0" => { survivor_id: @joiner.id },
          "1" => { survivor_id: @joiner.id }
        }
      } }
    end
    assert_response :redirect
  end

  test "a genuinely new survivor still saves" do
    assert_difference "Appearance.count", 1 do
      patch admin_episode_path(@e2), params: { episode: {
        title: "Two", appearances_attributes: { "0" => { survivor_id: @joiner.id } }
      } }
    end
  end
end
