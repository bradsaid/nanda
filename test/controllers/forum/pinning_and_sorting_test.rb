require "test_helper"

class Forum::PinningAndSortingTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @cat = forum_categories(:general)
    @owner = users(:one)
    @admin = users(:admin)

    # newest activity, no views, no replies
    @recent  = make("Recent one",  views: 0,   replies: 0, last_post_at: 1.minute.ago)
    # most views
    @popular = make("Popular one", views: 500, replies: 1, last_post_at: 2.days.ago)
    # most replies
    @active  = make("Active one",  views: 5,   replies: 6, last_post_at: 3.days.ago)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def make(title, views:, replies:, last_post_at:)
    t = Forum::Topic.create!(forum_category: @cat, user: @owner, title: title)
    t.posts.create!(user: @owner, body: "opening")
    replies.times { |i| t.posts.create!(user: users(:two), body: "reply #{i}") }
    t.update_columns(views_count: views, last_post_at: last_post_at)
    t
  end

  def sign_in_as(user) = post(session_path, params: { email_address: user.email_address, password: "password" })

  def titles_in_order
    css_select("tr.forum-topic-row a[href^='/forum/topics/']").map(&:text).reject(&:blank?)
  end

  test "recent is the default and leads with the newest activity" do
    get forum_path
    assert_equal "recent", assigns_sort
    assert_equal "Recent one", titles_in_order.first
  end

  test "popular orders by views" do
    get forum_path(sort: "popular")
    assert_equal "Popular one", titles_in_order.first
  end

  test "active orders by number of replies" do
    get forum_path(sort: "active")
    assert_equal "Active one", titles_in_order.first
  end

  test "an unknown sort falls back to recent instead of erroring" do
    get forum_path(sort: "'; DROP TABLE forum_topics; --")
    assert_response :success
    assert_equal "Recent one", titles_in_order.first
    assert Forum::Topic.exists?(@recent.id)
  end

  test "a pinned topic leads every sort" do
    @active.update!(pinned: true)
    %w[recent popular active].each do |sort|
      get forum_path(sort: sort)
      assert_equal "Active one", titles_in_order.first, "pinned topic must lead #{sort}"
    end
  end

  test "a moderator can pin and unpin" do
    sign_in_as(@admin)
    post forum_topic_pin_path(@recent)
    assert @recent.reload.pinned?
    delete forum_topic_pin_path(@recent)
    assert_not @recent.reload.pinned?
  end

  test "an ordinary member cannot pin" do
    sign_in_as(@owner)
    post forum_topic_pin_path(@recent)
    assert_not @recent.reload.pinned?
  end

  test "only moderators are shown the pin control" do
    sign_in_as(@owner)
    get forum_topic_path(@recent)
    assert_no_match(/Pin to top/, @response.body)
    sign_in_as(@admin)
    get forum_topic_path(@recent)
    assert_match(/Pin to top/, @response.body)
  end

  private

  def assigns_sort = @response.body[/btn-dark[^>]*>\s*(\w+)/, 1]&.downcase
end
