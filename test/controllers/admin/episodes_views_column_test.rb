require "test_helper"

class Admin::EpisodesViewsColumnTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    @episode = episodes(:one)
  end

  test "the views column is present without sorting by traffic" do
    get admin_episodes_path
    assert_response :success
    assert_select "th", text: /Views 30d/
  end

  test "it is still present when sorting by traffic" do
    get admin_episodes_path(sort: "traffic")
    assert_select "th", text: /Views 30d/
  end

  test "it shows a real count when the episode has traffic" do
    3.times { PageView.create!(path: "/episodes/#{@episode.id}", controller_name: "episodes", action_name: "show", method: "GET") }
    Rails.cache.clear
    get admin_episodes_path
    assert_select "td.text-end.small", text: "3"
  end

  test "an episode with no traffic shows a dash rather than a zero" do
    Rails.cache.clear
    get admin_episodes_path
    assert_select "td.text-end.small", text: "—"
  end

  test "views older than 30 days are not counted" do
    PageView.create!(path: "/episodes/#{@episode.id}", controller_name: "episodes",
                     action_name: "show", method: "GET", created_at: 40.days.ago)
    Rails.cache.clear
    get admin_episodes_path
    assert_select "td.text-end.small", text: "—"
  end

  test "the heading links to the traffic sort" do
    get admin_episodes_path
    assert_select "th a[href=?]", admin_episodes_path(sort: "traffic")
  end
end
