require "test_helper"

# Rendered pages carry rel="ugc nofollow noopener noreferrer" on outbound user links, including
# posts stored before the rule existed (no backfill needed), and member bios stay plain text.
class Forum::UgcLinksRenderingTest < ActionDispatch::IntegrationTest
  REL = "ugc nofollow noopener noreferrer".freeze

  setup do
    ENV["FORUM_ENABLED"] = "true"
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Link thread")
    @post  = @topic.posts.create!(user: users(:one), body: "Read [this](https://example.com/read) and see [our guide](/episodes).")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def post_links = css_select(".forum-post-body a[href]")

  test "the thread page puts the rel on outbound links and leaves ours alone" do
    get forum_topic_path(@topic)
    assert_response :success
    external = post_links.find { |a| a["href"] == "https://example.com/read" }
    assert_equal REL, external["rel"]
    internal = post_links.find { |a| a["href"] == "/episodes" }
    assert_nil internal["rel"]
  end

  test "a post stored before the rule existed is fixed up at render time" do
    @post.update_column(:body_html, %(<p><a href="https://old.example.com/page">old</a></p>))
    get forum_topic_path(@topic)
    old = post_links.find { |a| a["href"] == "https://old.example.com/page" }
    assert_equal REL, old["rel"]
  end

  test "a stored post that already carries a hostile rel is overridden when rendered" do
    @post.update_column(:body_html, %(<p><a href="https://old.example.com/page" rel="dofollow" target="_blank">old</a></p>))
    get forum_topic_path(@topic)
    old = post_links.find { |a| a["href"] == "https://old.example.com/page" }
    assert_equal REL, old["rel"]
    assert_nil old["target"]
  end

  test "member profile recent posts carry the rel" do
    get forum_profile_path(username: users(:one).username)
    assert_response :success
    external = post_links.find { |a| a["href"] == "https://example.com/read" }
    assert_equal REL, external["rel"]
  end

  test "the report form preview carries the rel" do
    post session_path, params: { email_address: users(:two).email_address, password: "password" }
    get new_forum_post_report_path(@post)
    assert_response :success
    external = post_links.find { |a| a["href"] == "https://example.com/read" }
    assert_equal REL, external["rel"]
  end

  test "a bio is shown as escaped plain text: no link is generated from it" do
    users(:one).update!(bio: %(Visit <a href="https://spam.example.com">my site</a> or https://spam.example.org))
    get forum_profile_path(username: users(:one).username)
    assert_response :success
    assert_select ".site-header a[href*='spam.example']", false
    assert_includes response.body, "&lt;a href=&quot;https://spam.example.com&quot;&gt;"
  end

  test "a bio is escaped in the member directory too" do
    users(:one).update!(bio: %(<a href="https://spam.example.com">x</a>))
    get forum_profiles_path
    assert_select "a[href*='spam.example']", false
  end
end
