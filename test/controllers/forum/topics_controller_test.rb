require "test_helper"

class Forum::TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
    @topic    = Forum::Topic.create!(forum_category: @category, user: users(:one), title: "Existing topic")
  end

  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "anonymous can view a topic" do
    get forum_topic_path(@topic)
    assert_response :success
    assert_select "h1", text: /Existing topic/
  end

  test "anonymous is prompted to sign in instead of getting a reply form" do
    get forum_topic_path(@topic)
    assert_match(/Sign in/, @response.body)
  end

  test "unverified user cannot create a topic" do
    sign_in_as(users(:unverified))
    assert_no_difference "Forum::Topic.count" do
      post forum_category_topics_path(@category), params: {
        topic: { title: "Try me", body: "hello" }
      }
    end
    assert_response :redirect
  end

  test "verified user creates a topic" do
    sign_in_as(users(:one))
    assert_difference "Forum::Topic.count", 1 do
      post forum_category_topics_path(@category), params: {
        topic: { title: "Hello there", body: "First post body." }
      }
    end
    t = Forum::Topic.order(:id).last
    assert_equal users(:one).id, t.user_id
    assert_equal 1, t.posts_count
    assert users(:one).forum_subscriptions.exists?(forum_topic: t), "author auto-subscribes"
  end

  test "public gets 404 when FORUM_ENABLED is not set" do
    ENV["FORUM_ENABLED"] = nil
    get forum_path
    assert_response :not_found
  end
end
