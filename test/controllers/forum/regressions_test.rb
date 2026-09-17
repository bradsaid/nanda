require "test_helper"

# Regression cases for forum bugs found in review. These mirror what the
# real browser forms actually submit, rather than hand-rolled param shapes —
# the original create test passed only because it posted a shape no form sends.
class Forum::RegressionsTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
    @owner    = users(:one)
    @other    = users(:two)
    @admin    = users(:admin)
    @topic    = Forum::Topic.create!(forum_category: @category, user: @owner, title: "Owner topic")
    @post     = @topic.posts.create!(user: @owner, body: "Owner body")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  # BUG 1: the real new-topic form submits title under topic[] but body under
  # forum_topic[] (see topics/new.html.slim). topic_params picks the
  # forum_topic key because it is present, so title is dropped.
  test "BUG1 verified user creates topic using REAL form param shape" do
    sign_in_as(@owner)
    assert_difference "Forum::Topic.count", 1 do
      post forum_topics_path, params: {
        topic:       { title: "Real form topic" },
        forum_topic: { body: "First post body." }
      }
    end
  end

  # BUG 2: require_ownership redirects but does not halt the action, so the
  # update still runs for a non-owner.
  test "BUG2 non-owner cannot rename someone elses topic" do
    sign_in_as(@other)
    patch forum_topic_path(@topic), params: { topic: { title: "Hijacked title" } }
    assert_equal "Owner topic", @topic.reload.title, "non-owner must not change the title"
  end

  # BUG 3: same halt bug on destroy -> any signed-in user soft-deletes any topic.
  test "BUG3 non-owner cannot delete someone elses topic" do
    sign_in_as(@other)
    delete forum_topic_path(@topic)
    assert_nil @topic.reload.deleted_at, "non-owner must not soft-delete the topic"
  end

  # BUG 4: require_editable has the same halt bug on posts.
  test "BUG4 non-owner cannot edit someone elses post" do
    sign_in_as(@other)
    patch forum_post_path(@post), params: { post: { body: "Vandalised" } }
    assert_equal "Owner body", @post.reload.body, "non-owner must not edit the post"
  end

  test "BUG5 non-owner cannot delete someone elses post" do
    sign_in_as(@other)
    delete forum_post_path(@post)
    assert_nil @post.reload.deleted_at, "non-owner must not soft-delete the post"
  end

  # BUG 6: can_edit_post? shows moderators an Edit link, but require_editable
  # passes allow_admin:false for edit/update, so the controller rejects them.
  test "BUG6 moderator can edit any post" do
    sign_in_as(@admin)
    patch forum_post_path(@post), params: { post: { body: "Moderated text" } }
    assert_equal "Moderated text", @post.reload.body, "moderator edit must be applied"
  end

  # BUG 7: forum_topics.last_post_user_id has an FK but no dependent: on User,
  # so deleting a user who left the last reply raises a FK violation.
  test "BUG7 destroying a user who was last poster does not raise" do
    other_topic = Forum::Topic.create!(forum_category: @category, user: @owner, title: "Another topic")
    other_topic.posts.create!(user: @other, body: "last reply here")
    assert_equal @other.id, other_topic.reload.last_post_user_id
    assert_nothing_raised { @other.destroy! }
  end

  # BUG 8: admins can tick "Locked (no new topics)" on a category but nothing
  # ever read the flag, so topic creation went through anyway.
  test "BUG8 locked category refuses new topics" do
    @category.update!(locked: true)
    sign_in_as(@owner)
    assert_no_difference "Forum::Topic.count" do
      post forum_topics_path, params: {
        forum_topic: { title: "Sneaking in", body: "body" }
      }
    end
    get new_forum_topic_path
    assert_redirected_to forum_path
  end

  test "BUG8b moderator can still post in a locked category" do
    @category.update!(locked: true)
    sign_in_as(@admin)
    assert_difference "Forum::Topic.count", 1 do
      post forum_topics_path, params: {
        forum_topic: { title: "Mod announcement", body: "body" }
      }
    end
  end

  # BUG 9: forum_categories.last_topic_at was read by the index but never written.
  test "BUG9 creating a topic stamps the category last_topic_at" do
    @category.update_columns(last_topic_at: nil)
    t = Forum::Topic.create!(forum_category: @category, user: @owner, title: "Stamps activity")
    assert_not_nil @category.reload.last_topic_at
    assert_in_delta t.created_at.to_f, @category.last_topic_at.to_f, 1.0
  end

  # BUG 10: forum_user_display fell back to the email local-part, publishing
  # part of a private address on posts and profiles.
  test "BUG10 display name never leaks the email local part" do
    nameless = User.create!(email_address: "secretlocalpart@example.com",
                            password: "password", email_verified_at: Time.current)
    assert_no_match(/secretlocalpart/, ApplicationController.helpers.forum_user_display(nameless))
  end

  # Guards the root cause of BUG1 directly: the rendered form's field names
  # must match the key TopicsController#topic_params reads.
  test "BUG1b rendered new-topic form posts every field under one key" do
    sign_in_as(@owner)
    get new_forum_topic_path
    assert_response :success
    assert_select "form input[name=?]",    "forum_topic[title]"
    assert_select "form textarea[name=?]", "forum_topic[body]"
    assert_select "form input[name=?]",    "topic[title]", count: 0
  end

  # BUG-01 (found in production QA): regenerating the slug on every title edit
  # moved the topic to a new URL and left the old one 404ing.
  test "BUG11 renaming a topic keeps its original URL" do
    sign_in_as(@owner)
    original = @topic.slug
    patch forum_topic_path(@topic), params: { topic: { title: "A completely different title" } }
    @topic.reload
    assert_equal "A completely different title", @topic.title, "the title must still change"
    assert_equal original, @topic.slug, "the slug must not move"
    get forum_topic_path(original)
    assert_response :success, "the original URL must still resolve"
  end

  test "BUG11b a brand new topic still gets a slug from its title" do
    sign_in_as(@owner)
    post forum_topics_path, params: {
      forum_topic: { title: "Fresh slug please", body: "body" }
    }
    assert_equal "fresh-slug-please", Forum::Topic.order(:id).last.slug
  end

  # BUG-02 (found in production QA): posts_count is a counter cache and keeps
  # counting soft-deleted posts, so the listing over-reported replies.
  test "BUG12 category reply count ignores soft-deleted posts" do
    3.times { |i| @topic.posts.create!(user: @other, body: "reply #{i}") }
    @topic.reload
    get forum_path
    assert_select "td[data-label=Replies]", { text: "3" }

    @topic.posts.order(:id).last.update!(deleted_at: Time.current)
    get forum_path
    assert_select "td[data-label=Replies]", { text: "2" },
      "a deleted reply must stop being counted"
  end

end
