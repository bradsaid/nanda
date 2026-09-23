require "test_helper"

# Forum pages were never recorded at all, so there was no way to tell whether
# anyone was reading the forum.
class ForumTrafficTrackingTest < ActionDispatch::IntegrationTest
  BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
            "(KHTML, like Gecko) Chrome/140.0 Safari/537.36".freeze

  setup do
    ENV["FORUM_ENABLED"] = "true"
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                  user: users(:one), title: "Tracked topic")
    @topic.posts.create!(user: users(:one), body: "hello")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def visit(path) = get(path, headers: { "HTTP_USER_AGENT" => BROWSER, "REMOTE_ADDR" => "203.0.113.50" })

  test "a forum page view is recorded and flagged as forum" do
    assert_difference "PageView.in_forum.count", 1 do
      visit forum_path
    end
    assert_equal true, PageView.order(:id).last.forum
  end

  test "a topic page counts too" do
    assert_difference "PageView.in_forum.count", 1 do
      visit forum_topic_path(@topic)
    end
  end

  test "a wiki page is not counted as forum traffic" do
    assert_difference "PageView.site.count", 1 do
      assert_no_difference "PageView.in_forum.count" do
        visit root_path
      end
    end
    assert_equal false, PageView.order(:id).last.forum
  end

  test "site figures still exclude the forum, so their meaning is unchanged" do
    visit forum_path
    visit root_path
    assert_equal 1, PageView.site.count
    assert_equal 1, PageView.in_forum.count
    assert_equal 2, PageView.count
  end

  test "the dashboard reports forum traffic separately" do
    visit forum_path
    Rails.cache.clear
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    get admin_root_path
    assert_response :success
    assert_match "Forum views today", @response.body
  end
end
