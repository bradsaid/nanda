require "test_helper"

class AuditPerformanceTest < ActionDispatch::IntegrationTest
  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36".freeze

  def with_memory_cache
    was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = was
  end

  test "the home page's aggregates are computed once, then served from cache" do
    with_memory_cache do
      get root_path
      assert_response :success

      queries = []
      cb = ->(*, payload) { queries << payload[:sql] if payload[:sql] =~ /COUNT/i && payload[:name] != "SCHEMA" }
      ActiveSupport::Notifications.subscribed(cb, "sql.active_record") { get root_path }
      assert_response :success
      assert_empty queries.grep(/FROM "(series|seasons|survivors|items)"/).reject { |q| q =~ /GROUP BY/ },
                   "headline counts should come from the cache on the second view"
    end
  end

  test "the survivors 'popular' sort reads view counts from the cache after the first request" do
    with_memory_cache do
      PageView.create!(path: "/survivors/test-survivor-a", controller_name: "x", action_name: "y",
                       method: "GET", ip_address: "8.8.8.8")
      get survivors_path(sort: "popular")
      assert_response :success

      PageView.delete_all
      queries = []
      cb = ->(*, payload) { queries << payload[:sql] if payload[:sql].to_s.include?('FROM "page_views"') }
      ActiveSupport::Notifications.subscribed(cb, "sql.active_record") { get survivors_path(sort: "popular") }
      assert_empty queries, "the page_views scan should not run again within the cache window"
    end
  end

  test "forum bots do not inflate a topic's view count, readers do" do
    ENV["FORUM_ENABLED"] = "true"
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Counted")
    topic.posts.create!(user: users(:one), body: "hi")

    get forum_topic_path(topic), headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" }
    get forum_topic_path(topic), headers: { "HTTP_USER_AGENT" => "" }
    assert_equal 0, topic.reload.views_count.to_i

    get forum_topic_path(topic), headers: { "HTTP_USER_AGENT" => BROWSER_UA }
    assert_equal 1, topic.reload.views_count.to_i
  ensure
    ENV["FORUM_ENABLED"] = nil
  end
end
