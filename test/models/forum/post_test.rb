require "test_helper"

class Forum::PostTest < ActiveSupport::TestCase
  setup do
    @user     = users(:one)
    @category = forum_categories(:general)
    @topic    = Forum::Topic.create!(forum_category: @category, user: @user, title: "Sample topic")
  end

  test "creates a post from markdown and renders sanitized HTML" do
    post = @topic.posts.create!(user: @user, body: "Hello **world**")
    assert_includes post.body_html, "<strong>world</strong>"
  end

  test "strips unsafe html from body" do
    post = @topic.posts.create!(user: @user, body: "<script>alert(1)</script> hi")
    assert_not_includes post.body_html.to_s, "<script"
  end

  test "requires body" do
    p = @topic.posts.new(user: @user, body: nil)
    assert_not p.valid?
  end

  test "updates topic counter and last_post_at on create" do
    assert_difference -> { @topic.reload.posts_count }, 1 do
      @topic.posts.create!(user: @user, body: "reply body")
    end
    assert @topic.reload.last_post_at.present?
  end

  test "soft delete keeps row but excludes from active scope" do
    post = @topic.posts.create!(user: @user, body: "temp")
    post.update!(deleted_at: Time.current)
    assert post.reload.persisted?
    assert_not_includes Forum::Post.active, post
  end
end
