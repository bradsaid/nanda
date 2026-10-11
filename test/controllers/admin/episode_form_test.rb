require "test_helper"

class Admin::EpisodeFormTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    @season   = seasons(:one)
    @location = locations(:one)
    @survivor = Survivor.create!(full_name: "Swap Me")
    @episode  = Episode.create!(season: @season, number_in_season: 5, title: "Edit target",
                                location: @location, air_date: Date.new(2025, 1, 1))
    @existing = @episode.appearances.create!(survivor: @survivor, role: "solo")
  end

  def episode_fields(extra = {})
    { season_id: @season.id, number_in_season: 6, title: "Brand new", location_id: @location.id }.merge(extra)
  end

  test "replacing a survivor's row (delete old, add new) keeps the survivor on the episode" do
    patch admin_episode_path(@episode), params: { episode: {
      appearances_attributes: {
        "0" => { id: @existing.id, _destroy: "1" },
        "1" => { survivor_id: @survivor.id, role: "duo" }
      }
    } }
    assert_redirected_to admin_episodes_path

    rows = @episode.reload.appearances.where(survivor_id: @survivor.id)
    assert_equal 1, rows.count, "the survivor must still be on the episode"
    assert_equal "duo", rows.first.role, "and it should be the replacement row"
  end

  test "the delete row may come after the replacement in the submission" do
    patch admin_episode_path(@episode), params: { episode: {
      appearances_attributes: {
        "0" => { survivor_id: @survivor.id, role: "trio" },
        "1" => { id: @existing.id, _destroy: "1" }
      }
    } }
    assert_redirected_to admin_episodes_path
    assert_equal ["trio"], @episode.reload.appearances.where(survivor_id: @survivor.id).pluck(:role)
  end

  test "a new row for a survivor who is already there (and not being deleted) is still dropped" do
    patch admin_episode_path(@episode), params: { episode: {
      appearances_attributes: { "0" => { survivor_id: @survivor.id, role: "duo" } }
    } }
    assert_redirected_to admin_episodes_path
    assert_equal 1, @episode.reload.appearances.where(survivor_id: @survivor.id).count
  end

  test "creating an episode with the same survivor listed twice saves it once instead of erroring" do
    assert_difference "Episode.count", 1 do
      post admin_episodes_path, params: { episode: episode_fields(
        appearances_attributes: {
          "0" => { survivor_id: @survivor.id, role: "solo" },
          "1" => { survivor_id: @survivor.id, role: "duo" }
        }
      ) }
    end
    created = Episode.find_by!(title: "Brand new")
    assert_equal 1, created.appearances.count
  end

  test "creating an episode whose number is already used in the season re-renders instead of a 500" do
    assert_no_difference "Episode.count" do
      post admin_episodes_path, params: { episode: episode_fields(number_in_season: 5) }
    end
    assert_response :unprocessable_entity
    assert_match(/duplicates an existing record/i, response.body)
  end
end
