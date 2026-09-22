require "test_helper"

class Forum::ProfileVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @user  = users(:one)
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                  user: @user, title: "Still here")
    @kept    = @topic.posts.create!(user: @user, body: "VISIBLE_POST")
    @deleted = @topic.posts.create!(user: @user, body: "DELETED_POST")
    @deleted.update!(deleted_at: Time.current)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  test "a soft-deleted post is not shown on the profile" do
    get forum_profile_path(username: @user.username)
    assert_response :success
    assert_match "VISIBLE_POST", @response.body
    assert_no_match(/DELETED_POST/, @response.body)
  end

  # The reported bug: the post itself is live, but its topic was removed.
  test "a post inside a removed topic is not shown or counted" do
    orphan_topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                        user: @user, title: "Removed later")
    orphan_topic.posts.create!(user: @user, body: "POST_IN_REMOVED_TOPIC")
    orphan_topic.update!(deleted_at: Time.current)

    get forum_profile_path(username: @user.username)
    assert_response :success
    assert_no_match(/POST_IN_REMOVED_TOPIC/, @response.body)

    visible = Forum::Post.active.joins(:forum_topic).where(forum_topics: { deleted_at: nil }, forum_posts: { user_id: @user.id }).count
    assert_select "div.h4", text: visible.to_s
  end
end
