require "test_helper"

# The forum_tester role exists so an external bot can exercise the forum
# before public launch WITHOUT holding any admin privileges. These tests pin
# both halves of that: it can reach the forum, and it can reach nothing else.
class Forum::TesterAccessTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = nil  # forum still dark to the public
    @category = forum_categories(:general)
    @tester = User.create!(email_address: "grok_tester_1@grok.test",
                           password: "testerpass1", username: "grok_tester_1",
                           email_verified_at: Time.current, role: :forum_tester)
    @owner = users(:one)
    @topic = Forum::Topic.create!(forum_category: @category, user: @owner, title: "Owner topic")
    @post  = @topic.posts.create!(user: @owner, body: "Owner body")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user, password: "password")
    post session_path, params: { email_address: user.email_address, password: password }
  end

  test "a forum tester can see the forum while it is dark to the public" do
    sign_in_as(@tester, password: "testerpass1")
    get forum_path
    assert_response :success
    get forum_topic_path(@topic)
    assert_response :success
  end

  test "an ordinary verified user still gets 404 on the dark forum" do
    sign_in_as(@owner)
    get forum_path
    assert_response :not_found
  end

  test "a forum tester can post, which is the point of the account" do
    sign_in_as(@tester, password: "testerpass1")
    assert_difference "Forum::Post.count", 1 do
      post forum_topic_posts_path(@topic), params: { post: { body: "Bot reply" } }
    end
    assert_equal @tester.id, Forum::Post.order(:id).last.user_id
  end

  test "a forum tester is refused everywhere under /admin" do
    sign_in_as(@tester, password: "testerpass1")
    [admin_root_path, admin_survivors_path, admin_episodes_path,
     admin_seasons_path, admin_changelog_index_path,
     admin_forum_categories_path, admin_forum_reports_path].each do |path|
      get path
      assert_redirected_to root_path, "#{path} must not be reachable by a forum tester"
    end
  end

  test "a forum tester holds no moderator powers inside the forum" do
    sign_in_as(@tester, password: "testerpass1")
    # Cannot edit or delete another member's post...
    patch forum_post_path(@post), params: { post: { body: "moderated" } }
    assert_equal "Owner body", @post.reload.body
    delete forum_post_path(@post)
    assert_nil @post.reload.deleted_at
    # ...nor someone else's topic.
    delete forum_topic_path(@topic)
    assert_nil @topic.reload.deleted_at
  end

  test "a forum tester is not treated as an admin anywhere" do
    tester = User.find_by(email_address: "grok_tester_1@grok.test")
    assert tester.forum_tester?
    assert_not tester.admin?
    assert_not tester.episode_editor?
  end
end
