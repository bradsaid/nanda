require "test_helper"

# Public member profiles are thin pages of user-generated text: "noindex, follow" (meta tag and
# X-Robots-Tag header) and never in the sitemap. The member directory is the same.
class Forum::ProfileRobotsTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    Rails.cache.clear
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def robots_meta = css_select('meta[name="robots"]').map { |n| n["content"] }

  test "a public profile is noindex, follow in the meta tag and the header" do
    get forum_profile_path(username: users(:one).username)
    assert_response :success
    assert_equal [ "noindex, follow" ], robots_meta
    assert_equal "noindex, follow", response.headers["X-Robots-Tag"]
  end

  test "profile lookup is case-insensitive but still noindex, follow" do
    get "/forum/users/#{users(:one).username.upcase}"
    assert_response :success
    assert_equal "noindex, follow", response.headers["X-Robots-Tag"]
  end

  test "the member directory stays noindex, follow" do
    get forum_profiles_path
    assert_equal [ "noindex, follow" ], robots_meta
    assert_equal "noindex, follow", response.headers["X-Robots-Tag"]
  end

  test "the edit profile page is noindex, nofollow" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    get forum_edit_profile_path(username: users(:one).username)
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "a forum thread is still indexable (no robots tag)" do
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Indexable thread")
    topic.posts.create!(user: users(:one), body: "Hello")
    get forum_topic_path(topic)
    assert_response :success
    assert_empty robots_meta
    assert_nil response.headers["X-Robots-Tag"]
  end

  test "the sitemap lists forum topics but no member profile or directory URL, forum open or closed" do
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Sitemap thread")
    topic.posts.create!(user: users(:one), body: "Hello")

    [ "true", nil ].each do |flag|
      ENV["FORUM_ENABLED"] = flag
      Rails.cache.clear
      get "/sitemap.xml"
      assert_response :success
      locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
      assert_equal flag.present?, locs.any? { |l| l.end_with?("/forum/topics/#{topic.slug}") }, "forum flag #{flag.inspect}"
      assert_empty locs.grep(%r{/forum/users}), "no profile or member-directory URLs in the sitemap"
      User.pluck(:username).compact.each do |name|
        assert locs.none? { |l| l.downcase.end_with?("/#{name.downcase}") }, "no URL ends in the username #{name}"
      end
    end
  end
end
