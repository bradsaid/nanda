require "test_helper"

class Admin::FishBasketTrapTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "the trap type suggestions offer Fish Basket, not Fish Trap" do
    sign_in(users(:admin))
    get edit_admin_episode_path(episodes(:one))
    assert_response :success
    assert_select "datalist#trap-types-datalist option[value=?]", "Fish Basket"
    assert_select "datalist#trap-types-datalist option[value=?]", "Fish Trap", 0
  end

  test "a food source caught in a fish basket reads 'Fish Basket', not 'Fish Basket Trap'" do
    episode = episodes(:one)
    trap = episode.episode_traps.create!(trap_type: "Fish Basket")
    episode.food_sources.create!(category: "animal", name: "Tilapia", episode_trap: trap)
    get episode_path(episode)
    assert_response :success
    assert_match(/Fish Basket/, response.body)
    assert_no_match(/Fish Basket Trap/, response.body)
  end
end
