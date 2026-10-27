require "test_helper"

class Admin::EpisodeFoodQuantityTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    @episode = Episode.first
    @animal = @episode.food_sources.create!(name: "iguana", category: "animal", method: "hunted", quantity: 4)
  end

  test "edit form shows the saved quantity of an existing animal food source" do
    get edit_admin_episode_path(@episode)
    assert_response :success
    assert_select "input.food-source-quantity[name=?][value=?]",
                  "episode[food_sources_attributes][0][quantity]", "4"
  end

  test "a plant keeps its quantity: shown on edit, not cleared on save" do
    plant = @episode.food_sources.create!(name: "coconut", category: "plant", method: "foraged", quantity: 6)
    assert_equal 6, plant.reload.quantity

    get edit_admin_episode_path(@episode)
    assert_select "input.food-source-quantity[value=?]", "6"

    patch admin_episode_path(@episode), params: { episode: {
      food_sources_attributes: { "0" => { id: plant.id, name: "coconut", category: "plant", method: "foraged", quantity: "6" } }
    } }
    assert_equal 6, plant.reload.quantity
  end

  test "saving the edit form without touching quantity keeps it" do
    patch admin_episode_path(@episode), params: { episode: {
      food_sources_attributes: { "0" => { id: @animal.id, name: "iguana", category: "animal", method: "hunted", quantity: "4" } }
    } }
    assert_equal 4, @animal.reload.quantity
  end
end
