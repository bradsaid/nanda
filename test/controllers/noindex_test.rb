require "test_helper"

# Account-only and low-value pages stay out of search results (meta robots tag +
# X-Robots-Tag header); public content stays indexable.
class NoindexTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @owner = users(:one)
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: @owner, title: "A public topic")
    @post  = @topic.posts.create!(user: @owner, body: "Hello")
    @other_post = @topic.posts.create!(user: users(:two), body: "Reply from someone else")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user) = post(session_path, params: { email_address: user.email_address, password: "password" })

  def robots_meta = css_select("meta[name=robots]").map { |m| m["content"] }

  def assert_noindex(path, value = "noindex, nofollow", status: :success)
    get path
    assert_response status, "#{path} should be #{status}"
    assert_equal value, response.headers["X-Robots-Tag"], "X-Robots-Tag on #{path}"
    assert_equal [ value ], robots_meta, "robots meta on #{path}" if response.media_type == "text/html" && response.successful?
  end

  def assert_indexable(path)
    get path
    assert_response :success, path
    assert_nil response.headers["X-Robots-Tag"], "X-Robots-Tag on #{path}"
    assert_empty robots_meta, "robots meta on #{path}"
  end

  test "sign-in, signup and password pages are noindex" do
    assert_noindex new_session_path
    assert_noindex signup_path
    assert_noindex new_password_path
  end

  test "a failed sign-in re-render is noindex too" do
    post session_path, params: { email_address: "nobody@example.com", password: "nope" }
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "password reset, email verification and email change links are noindex" do
    token = @owner.password_reset_token
    assert_noindex edit_password_path(token: token)

    pending = users(:unverified)
    assert_noindex email_verification_path(token: pending.generate_token_for(:email_verification))

    @owner.update!(pending_email_address: "fresh@example.com")
    assert_noindex email_change_path(token: @owner.generate_token_for(:email_change))
  end

  test "forum composers and report/edit pages are noindex" do
    sign_in_as(@owner)
    assert_noindex new_forum_topic_path
    assert_noindex edit_forum_topic_path(@topic)
    assert_noindex edit_forum_post_path(@post)
    assert_noindex forum_edit_profile_path(username: @owner.username)

    assert_noindex new_forum_post_report_path(@other_post)
  end

  test "the member directory is noindex but followable; profiles stay indexable" do
    assert_noindex forum_profiles_path, "noindex, follow"
    assert_indexable forum_profile_path(username: @owner.username)
  end

  test "the mentions typeahead JSON is noindex" do
    sign_in_as(@owner)
    get forum_mentions_path(q: "a", type: "survivor")
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "public forum and site content stays indexable" do
    assert_indexable forum_path
    assert_indexable forum_topic_path(@topic)
    assert_indexable forum_guidelines_path
    assert_indexable root_path
    assert_indexable survivors_path
    assert_indexable episodes_path
    assert_indexable about_path
  end

  test "the admin area sends the header as well" do
    sign_in_as(users(:admin))
    get admin_root_path
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_equal [ "noindex, nofollow" ], robots_meta
  end

  test "a page's own content_for :robots still wins for the meta tag" do
    get items_path(q: "rope")
    assert_equal [ "noindex, follow" ], robots_meta
  end
end
