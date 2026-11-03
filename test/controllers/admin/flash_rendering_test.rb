require "test_helper"

# The application layout renders shared/flash once. Several views used to
# render the flash again themselves, so every notice appeared in two stacked
# boxes.
class Admin::FlashRenderingTest < ActionDispatch::IntegrationTest
  def flash_boxes(text)
    css_select(".alert").select { |el| el.text.include?(text) }
  end

  def sign_in_admin
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
  end

  test "updating an episode shows 'Episode updated.' exactly once" do
    sign_in_admin
    episode = Episode.create!(season: seasons(:one), number_in_season: 9, title: "Flash target",
                              location: locations(:one), air_date: Date.new(2025, 1, 1))

    patch admin_episode_path(episode), params: { episode: { title: "Renamed" } }
    assert_redirected_to admin_episodes_path
    follow_redirect!

    assert_response :success
    assert_equal 1, flash_boxes("Episode updated.").size
  end

  test "updating a survivor shows its notice exactly once" do
    sign_in_admin
    survivor = Survivor.create!(full_name: "Flash Survivor")

    patch admin_survivor_path(survivor), params: { survivor: { full_name: "Flash Renamed" } }
    follow_redirect!

    assert_equal 1, flash_boxes("Survivor updated.").size
  end

  test "a failed sign-in shows its alert exactly once" do
    post session_path, params: { email_address: users(:admin).email_address, password: "wrong" }
    follow_redirect!

    assert_equal 1, flash_boxes("Invalid email or password").size
  end
end
