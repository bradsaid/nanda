require "test_helper"

# Removing a topic or post recorded only when, never who — so "who deleted
# this?" had no answer, with two moderators and self-deleting authors.
class Forum::DeletionAttributionTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @author = users(:one)
    @admin  = users(:admin)
    @topic  = Forum::Topic.create!(forum_category: forum_categories(:general),
                                   user: @author, title: "Attributed topic")
    @post   = @topic.posts.create!(user: @author, body: "body")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(u) = post(session_path, params: { email_address: u.email_address, password: "password" })

  test "an author removing their own topic is recorded" do
    sign_in_as(@author)
    delete forum_topic_path(@topic)
    @topic.reload
    assert @topic.deleted_at.present?
    assert_equal @author, @topic.deleted_by
  end

  test "a moderator removing someone else's topic is recorded as the moderator" do
    sign_in_as(@admin)
    delete forum_topic_path(@topic)
    assert_equal @admin, @topic.reload.deleted_by
  end

  test "removing a post is recorded" do
    sign_in_as(@author)
    delete forum_post_path(@post)
    assert_equal @author, @post.reload.deleted_by
  end

  test "removing a post from the moderation queue records the moderator" do
    reporter = users(:two)
    report = Forum::Report.create!(reporter: reporter, reportable: @post, reason: :spam)
    sign_in_as(@admin)
    patch admin_forum_report_path(report), params: { decision: "remove_post" }
    assert_equal @admin, @post.reload.deleted_by
  end

  test "live content has no remover" do
    assert_nil @topic.deleted_by
    assert_nil @post.deleted_by
  end

  test "deleting the account that removed something does not fail on the key" do
    sign_in_as(@admin)
    delete forum_topic_path(@topic)
    assert_equal @admin, @topic.reload.deleted_by
    assert_nothing_raised { @admin.destroy! }
    assert_nil @topic.reload.deleted_by
  end

  test "the dashboard names who removed what" do
    sign_in_as(@author)
    delete forum_topic_path(@topic)
    Rails.cache.clear
    sign_in_as(@admin)
    get admin_root_path
    assert_response :success
    assert_match "Recently removed from the forum", @response.body
    assert_match "Attributed topic", @response.body
  end
end
