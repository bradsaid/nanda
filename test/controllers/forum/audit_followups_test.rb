require "test_helper"

class Forum::AuditFollowupsTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @owner = users(:one)
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: @owner, title: "Follow-ups")
    @post  = @topic.posts.create!(user: @owner, body: "Original")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user) = post(session_path, params: { email_address: user.email_address, password: "password" })

  def upload(content, name, type)
    f = Tempfile.new(["up", File.extname(name)], binmode: true)
    f.write(content); f.rewind
    Rack::Test::UploadedFile.new(f.path, type, original_filename: name)
  end

  test "editing a post cannot attach a text file renamed .jpg" do
    sign_in_as(@owner)
    patch forum_post_path(@post),
          params: { post: { body: "edited", images: [upload("plain text pretending", "fake.jpg", "image/jpeg")] } }
    assert_response :unprocessable_content
    assert_match(/not a real image/i, @response.body)
    assert_equal "Original", @post.reload.body
    assert_not @post.images.attached?
  end

  test "editing a post's text still works" do
    sign_in_as(@owner)
    patch forum_post_path(@post), params: { post: { body: "edited fine" } }
    assert_redirected_to forum_topic_path(@topic, anchor: "post-#{@post.id}")
    assert_equal "edited fine", @post.reload.body
  end

  test "a banned member's profile is not found by the public, but staff can still see it" do
    banned = users(:banned)
    assert banned.username.present?, "fixture needs a username"

    get forum_profile_path(username: banned.username)
    assert_response :not_found

    sign_in_as(users(:admin))
    get forum_profile_path(username: banned.username)
    assert_response :success
  end

  test "an ordinary member's profile still shows" do
    get forum_profile_path(username: @owner.username)
    assert_response :success
  end

  test "filing a report sends the moderator email through the queue" do
    sign_in_as(users(:two))
    assert_enqueued_emails 1 do
      post forum_post_report_path(@post), params: { report: { reason: "spam" } }
    end
  end
end
