require "test_helper"

class Admin::DashboardForumCountsTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                  user: users(:one), title: "Counted topic")
  end

  test "a removed post is not counted in the last 24 hours" do
    @topic.posts.create!(user: users(:one), body: "kept")
    doomed = @topic.posts.create!(user: users(:one), body: "removed")
    get admin_root_path
    before = css_select("div.h4").map(&:text)

    Rails.cache.clear
    doomed.update!(deleted_at: Time.current)
    get admin_root_path
    after = css_select("div.h4").map(&:text)

    assert_not_equal before, after, "deleting a post must change the dashboard count"
  end

  test "posts inside a removed topic are not counted" do
    @topic.posts.create!(user: users(:one), body: "one")
    Rails.cache.clear
    get admin_root_path
    with_topic = css_select("div.h4").map(&:text)

    @topic.update!(deleted_at: Time.current)
    Rails.cache.clear
    get admin_root_path
    without_topic = css_select("div.h4").map(&:text)

    assert_not_equal with_topic, without_topic,
      "removing a topic must drop its posts from the count"
  end
end
