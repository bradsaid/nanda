require "test_helper"

# Forum threads and profiles: DiscussionForumPosting JSON-LD, and titles/descriptions built from
# the thread's first post and the member's public profile.
class ForumSeoTest < ActionDispatch::IntegrationTest
  def json_ld
    css_select('script[type="application/ld+json"]').flat_map { |n| parsed = JSON.parse(n.text); parsed.is_a?(Array) ? parsed : [ parsed ] }
  end

  def schema(type) = json_ld.find { |s| s["@type"] == type }

  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]

  # ---------- structured data ----------

  test "a public forum thread carries valid DiscussionForumPosting JSON-LD" do
    ENV["FORUM_ENABLED"] = "true"
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Best </script> knife? & why")
    topic.posts.create!(user: users(:one), body: "My **first** post about knives </script><b>x</b>. Mail me at secret@example.com for more.")
    12.times { |i| topic.posts.create!(user: users(:two), body: "Reply number #{i + 1}") }
    topic.update!(views_count: 42)

    get forum_topic_path(topic)
    assert_response :success
    # The raw page can never be broken out of by user text.
    assert_equal 1, css_select('script[type="application/ld+json"]').size
    refute_match %r{</script>x}, response.body
    posting = schema("DiscussionForumPosting")
    assert_equal "Best </script> knife? & why", posting["headline"]
    assert_equal "My first post about knives </script>x. Mail me at for more.", posting["text"]
    assert_no_match(/secret@example\.com/, css_select('script[type="application/ld+json"]').first.text)
    assert_no_match(/secret@example\.com/, css_select('meta[name="description"]').first["content"])
    assert_equal "alice", posting["author"]["name"]
    assert_equal "http://www.example.com/forum/users/alice", posting["author"]["url"]
    assert_equal "http://www.example.com/forum/topics/#{topic.slug}", posting["url"]
    assert_equal posting["url"], posting["mainEntityOfPage"]["@id"]
    assert_equal "http://www.example.com/forum", posting["isPartOf"]["url"]
    assert_equal 12, posting["commentCount"]
    stats = posting["interactionStatistic"].to_h { |s| [ s["interactionType"].split("/").last, s["userInteractionCount"] ] }
    assert_equal({ "CommentAction" => 12, "ViewAction" => 42 }, stats)
    assert_equal 10, posting["comment"].size
    assert_equal "Reply number 1", posting["comment"].first["text"]
    assert_equal "Comment", posting["comment"].first["@type"]
    assert_equal "bob", posting["comment"].first["author"]["name"]
    assert Time.iso8601(posting["datePublished"]) <= Time.iso8601(posting["dateModified"])
    ld_text = css_select('script[type="application/ld+json"]').first.text
    assert_no_match(/[\w.+-]+@[\w-]+\.[\w.]+/, ld_text, "no email address anywhere in the structured data")
  ensure
    ENV["FORUM_ENABLED"] = nil
  end

  test "deleted replies are left out of the thread JSON-LD and a deleted topic is a 404" do
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Hidden thread")
    topic.posts.create!(user: users(:one), body: "Opening")
    reply = topic.posts.create!(user: users(:two), body: "Soon deleted reply")

    ENV["FORUM_ENABLED"] = "true"
    reply.update!(deleted_at: Time.current)
    get forum_topic_path(topic)
    posting = schema("DiscussionForumPosting")
    assert_nil posting["comment"], "soft-deleted replies are not exposed"
    assert_equal 0, posting["commentCount"]
    refute_includes response.body, "Soon deleted reply"

    topic.update!(deleted_at: Time.current)
    get forum_topic_path(topic)
    assert_response :not_found
  ensure
    ENV["FORUM_ENABLED"] = nil
  end

  test "the hidden preview forum (staff only) emits no DiscussionForumPosting" do
    ENV["FORUM_ENABLED"] = nil
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Preview thread")
    topic.posts.create!(user: users(:one), body: "Preview opening")
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    get forum_topic_path(topic)
    assert_response :success
    assert_nil schema("DiscussionForumPosting")
  end

  test "a banned author is named but not linked" do
    ENV["FORUM_ENABLED"] = "true"
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:banned), title: "Banned author thread")
    topic.posts.create!(user: users(:banned), body: "Posting while banned")
    get forum_topic_path(topic)
    author = schema("DiscussionForumPosting")["author"]
    assert_equal "banned_user", author["name"]
    assert_nil author["url"]
  ensure
    ENV["FORUM_ENABLED"] = nil
  end

  # ---------- titles and descriptions ----------

  def with_forum
    ENV["FORUM_ENABLED"] = "true"
    yield
  ensure
    ENV["FORUM_ENABLED"] = nil
  end

  test "a forum thread's description comes from its first post" do
    with_forum do
      a = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Thread about fire")
      a.posts.create!(user: users(:one), body: "How do you **start a fire** with a ferro rod in the rain? I keep failing at the tinder stage.")
      b = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Thread about water")
      b.posts.create!(user: users(:one), body: "Boiling versus filtering " + ("water on the trail " * 20))
      b.posts.create!(user: users(:two), body: "Reply that must never become the description")

      get forum_topic_path(a)
      assert_equal "How do you start a fire with a ferro rod in the rain? I keep failing at the tinder stage.", description
      desc_a = description
      get forum_topic_path(b)
      assert_not_equal desc_a, description
      assert_operator description.length, :<=, 160
      assert_match(/\ABoiling versus filtering water on the trail/, description)
      assert description.end_with?("…")
      assert_no_match(/never become/, description)
      assert_equal "Thread about water — Forum", title
    end
  end

  test "thread pages after the first say which page they are" do
    with_forum do
      t = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Long thread")
      t.posts.create!(user: users(:one), body: "Opening post of a long thread.")
      (Forum::Topic::POSTS_PER_PAGE + 1).times { |i| t.posts.create!(user: users(:two), body: "Reply #{i}") }
      get forum_topic_path(t)
      assert_equal "Long thread — Forum", title
      get forum_topic_path(t, page: 2)
      assert_equal "Long thread — Forum — Page 2", title
      assert_equal "Opening post of a long thread. (page 2)", description
    end
  end

  test "forum list pages paginate title and description" do
    with_forum do
      (Forum::TopicsController::TOPICS_PER_PAGE + 1).times do |i|
        Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: format("Listing topic %03d", i))
      end
      get forum_path
      assert_equal "Forum — Naked & Afraid Fan Wiki", title
      page1_desc = description
      get forum_path(page: 2)
      assert_equal "Forum — Naked & Afraid Fan Wiki — Page 2", title
      assert_equal "#{page1_desc} (page 2)", description
    end
  end

  test "forum profile descriptions are generated from public profile data" do
    with_forum do
      alice = users(:one)
      alice.update!(bio: "Bushcraft hobbyist & <b>knife</b> nerd. Contact me at alice@example.com")
      topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: alice, title: "Alice topic")
      topic.posts.create!(user: alice, body: "Alice post")
      bob = users(:two)

      get forum_profile_path(username: "alice")
      assert_response :success
      desc = description
      assert_match(/\Aalice joined the Naked & Afraid fan forum in #{Regexp.escape(alice.created_at.strftime('%B %Y'))} and has written 1 post and started 1 topic\./, desc)
      assert_includes desc, "Bushcraft hobbyist"
      assert_no_match(/@example\.com|<b>|alice@/, desc)
      assert_operator desc.length, :<=, 160

      get forum_profile_path(username: "bob")
      assert_not_equal desc, description
      assert_match(/\Abob joined the Naked & Afraid fan forum/, description)
      assert_match(/0 posts and started 0 topics/, description)
      assert_no_match(/#{Regexp.escape(bob.email_address)}/, response.body.scan(/<meta name="description"[^>]*>/).join)
    end
  end

  test "a post that uses a Markdown heading does not add a second h1 to the thread page" do
    with_forum do
      t = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Heading thread")
      t.posts.create!(user: users(:one), body: "# Big heading inside a post\n\nBody text.")
      get forum_topic_path(t)
      assert_equal 1, css_select("h1").size
      assert_select ".forum-post-body h2", "Big heading inside a post"
    end
  end
end
