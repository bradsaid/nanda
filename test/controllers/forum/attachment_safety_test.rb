require "test_helper"

# Round 3 QA: a .txt or .pdf attachment 500'd the topic page permanently, and a
# text file renamed .jpg was accepted outright.
class Forum::AttachmentSafetyTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
    @owner = users(:one)
    @topic = Forum::Topic.create!(forum_category: @category, user: @owner, title: "Attachment safety")
    @topic.posts.create!(user: @owner, body: "Opening post")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user) = post(session_path, params: { email_address: user.email_address, password: "password" })

  def upload(content, name, type)
    f = Tempfile.new(["up", File.extname(name)], binmode: true)
    f.write(content); f.rewind
    Rack::Test::UploadedFile.new(f.path, type, original_filename: name)
  end

  def real_png
    # 1x1 PNG
    Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
  end

  test "a text file is refused instead of being attached" do
    sign_in_as(@owner)
    assert_no_difference "Forum::Post.count" do
      post forum_topic_posts_path(@topic),
           params: { post: { body: "has a txt", images: [upload("just words", "notes.txt", "text/plain")] } }
    end
    assert_response :unprocessable_content
  end

  test "a text file renamed .jpg is refused by its bytes, not its name" do
    sign_in_as(@owner)
    assert_no_difference "Forum::Post.count" do
      post forum_topic_posts_path(@topic),
           params: { post: { body: "disguised", images: [upload("plain text pretending", "fake.jpg", "image/jpeg")] } }
    end
    assert_response :unprocessable_content
    assert_match(/not a real image/i, @response.body)
  end

  test "a genuine png still attaches" do
    sign_in_as(@owner)
    assert_difference "Forum::Post.count", 1 do
      post forum_topic_posts_path(@topic),
           params: { post: { body: "real image", images: [upload(real_png, "real.png", "image/png")] } }
    end
  end

  # The draft-wipe half of the report.
  test "a rejected reply keeps the author's text in the composer" do
    sign_in_as(@owner)
    post forum_topic_posts_path(@topic),
         params: { post: { body: "DRAFT_MUST_SURVIVE", images: [upload("nope", "notes.txt", "text/plain")] } }
    assert_response :unprocessable_content
    assert_match "DRAFT_MUST_SURVIVE", @response.body
  end

  # A blob already stored that cannot be transformed must not break the page.
  test "an existing non-variable attachment renders as a link, not a 500" do
    p = @topic.posts.create!(user: @owner, body: "legacy bad attachment")
    p.images.attach(io: StringIO.new("words"), filename: "legacy.txt", content_type: "text/plain")
    p.save!(validate: false)
    get forum_topic_path(@topic)
    assert_response :success
    assert_match "legacy.txt", @response.body
  end
end
