require "test_helper"

# The forum is one space, not a set of categories: /forum is the topic list.
class Forum::SingleForumTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
    @owner = users(:one)
    @topic = Forum::Topic.create!(forum_category: @category, user: @owner, title: "Visible on the index")
    @topic.posts.create!(user: @owner, body: "Opening post")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user) = post(session_path, params: { email_address: user.email_address, password: "password" })

  test "/forum lists topics directly, with no category browsing step" do
    get forum_path
    assert_response :success
    assert_select "a[href=?]", forum_topic_path(@topic), text: "Visible on the index"
  end

  test "topics from every category appear in the one list" do
    other = Forum::Topic.create!(forum_category: forum_categories(:season), user: @owner, title: "From season talk")
    get forum_path
    assert_select "a[href=?]", forum_topic_path(other), text: "From season talk"
  end

  test "old category links redirect instead of 404ing" do
    get "/forum/categories/general-discussion"
    assert_redirected_to "/forum"
    get "/forum/categories"
    assert_redirected_to "/forum"
  end

  test "creating a topic needs no category and lands in the default one" do
    sign_in_as(@owner)
    get new_forum_topic_path
    assert_response :success
    assert_select "select[name*=category]", { count: 0 }, "author must not be asked to pick a category"

    assert_difference "Forum::Topic.count", 1 do
      post forum_topics_path, params: { forum_topic: { title: "No category needed", body: "body" } }
    end
    assert_equal Forum::Category.default.id, Forum::Topic.order(:id).last.forum_category_id
  end

  test "a topic page shows no category breadcrumb" do
    get forum_topic_path(@topic)
    assert_response :success
    assert_no_match(/General Discussion/, @response.body)
  end
end
