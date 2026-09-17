require "test_helper"

# Fixes for the browser-QA round. Each test fails against the code that
# shipped before it.
class Forum::Round2FixesTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
    @owner = users(:one)
    @other = users(:two)
    @topic = Forum::Topic.create!(forum_category: @category, user: @owner, title: "Round 2 topic")
    @topic.posts.create!(user: @owner, body: "Opening post")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user) = post(session_path, params: { email_address: user.email_address, password: "password" })

  def big_upload(bytes:, type: "image/jpeg", name: "big.jpg")
    file = Tempfile.new(["big", ".jpg"], binmode: true)
    file.write("\xFF\xD8\xFF\xE0".b + ("\0".b * bytes))
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, original_filename: name)
  end

  # BUG-3: the rejected blob stayed assigned in memory, and rendering a variant
  # preview of it raised "Cannot get a signed_id for a new record".
  test "an oversized avatar is rejected without a 500" do
    sign_in_as(@owner)
    patch forum_profile_path(username: @owner.username),
          params: { user: { bio: "kept text", avatar: big_upload(bytes: 6.megabytes) } }
    assert_response :unprocessable_entity
    assert_no_match(/something went wrong/i, @response.body)
    assert_match(/under 5 MB/i, @response.body, "the reason must be shown")
  end

  # BUG-1/2 root cause: flash was set everywhere and rendered nowhere.
  test "flash messages actually reach the page" do
    sign_in_as(@other)
    patch forum_topic_path(@topic), params: { topic: { title: "not mine" } }
    follow_redirect!
    assert_match "Not your topic.", @response.body, "alerts must be visible to the user"
  end

  test "a failed topic submission keeps what the author typed" do
    sign_in_as(@owner)
    post forum_category_topics_path(@category), params: {
      forum_topic: { title: "x", body: "a body worth keeping" }  # title too short
    }
    assert_response :unprocessable_entity
    assert_match "a body worth keeping", @response.body, "the composer must not be wiped"
  end

  # BUG-4: replying from page 2 redirected to page 1.
  test "replying from a later page returns to that page" do
    (Forum::Topic::POSTS_PER_PAGE + 2).times { |i| @topic.posts.create!(user: @other, body: "filler #{i}") }
    sign_in_as(@other)
    post forum_topic_posts_path(@topic), params: { post: { body: "reply from page two" } }
    new_post = Forum::Post.order(:id).last
    assert_redirected_to forum_topic_path(@topic, page: 2, anchor: "post-#{new_post.id}")
  end

  # BUG-8: destroy was permitted but the control was never rendered.
  test "an author sees a delete control on their own topic" do
    sign_in_as(@owner)
    get forum_topic_path(@topic)
    assert_select "form[action=?][method=post]", forum_topic_path(@topic)
    assert_match "Delete topic", @response.body
  end

  test "a non-owner sees no delete control" do
    sign_in_as(@other)
    get forum_topic_path(@topic)
    assert_no_match(/Delete topic/, @response.body)
  end
  # Round 4: /forum/topics/:slug carries no category, but slugs were unique
  # only per category, so one topic permanently shadowed the other.
  test "two topics with the same title in different categories get distinct urls" do
    sign_in_as(@owner)
    other_category = forum_categories(:season)
    a = Forum::Topic.create!(forum_category: @category,      user: @owner, title: "Shared headline")
    b = Forum::Topic.create!(forum_category: other_category, user: @owner, title: "Shared headline")
    assert_not_equal a.slug, b.slug, "slugs must not collide across categories"

    get forum_topic_path(a); assert_response :success
    assert_select "h1", text: /Shared headline/
    get forum_topic_path(b); assert_response :success
  end

  # Round 4: the edit route existed but nothing linked to it.
  test "an author is offered a way to rename their topic" do
    sign_in_as(@owner)
    get forum_topic_path(@topic)
    assert_select "a[href=?]", edit_forum_topic_path(@topic), text: "Edit title"
  end

  test "a non-owner is not offered the rename control" do
    sign_in_as(@other)
    get forum_topic_path(@topic)
    assert_select "a[href=?]", edit_forum_topic_path(@topic), count: 0
  end
end
