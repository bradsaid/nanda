require "test_helper"

# Every paginated forum list answers 404 for ?page=N past its last page and 301s malformed
# page values to the clean URL (Paginatable). The forum index itself is covered by
# topic_list_pagination_test.rb; this file covers the thread page, the member directory and
# the admin member list.
class Forum::PaginationBoundsTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Long thread")
    @topic.posts.create!(user: users(:one), body: "Opening post")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def canonical = css_select("link[rel=canonical]").first["href"]

  # ---- thread (posts) pages ----

  test "a thread with one page: page 1 is 200 and page 2 is 404" do
    get forum_topic_path(@topic)
    assert_response :success
    get forum_topic_path(@topic, page: 2)
    assert_response :not_found
  end

  test "the last page of a long thread is 200 and the next one is 404, without counting a view" do
    Forum::Topic::POSTS_PER_PAGE.times { |i| @topic.posts.create!(user: users(:two), body: "Reply #{i}") } # 21 posts, 2 pages
    get forum_topic_path(@topic, page: 2), headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux) Firefox/120" }
    assert_response :success
    assert_equal "http://www.example.com/forum/topics/#{@topic.slug}?page=2", canonical

    before = @topic.reload.views_count
    get forum_topic_path(@topic, page: 3), headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux) Firefox/120" }
    assert_response :not_found
    assert_equal before, @topic.reload.views_count
  end

  test "malformed thread page values redirect to the clean thread URL" do
    %w[abc 0 -1 1 01 2.5].each do |bad|
      get "/forum/topics/#{@topic.slug}", params: { page: bad }
      assert_response :moved_permanently, bad
      assert_redirected_to "http://www.example.com/forum/topics/#{@topic.slug}"
    end
  end

  # ---- member directory ----

  test "member directory: page 1 is 200, past the last page is 404" do
    get forum_profiles_path
    assert_response :success
    get forum_profiles_path(page: 2)
    assert_response :not_found
  end

  test "member directory: the last page is 200 and the next is 404" do
    (Forum::ProfilesController::PER_PAGE + 1).times do |i|
      User.create!(email_address: "member#{i}@example.com", password: "password", username: "member_#{i}", email_verified_at: 1.day.ago)
    end
    get forum_profiles_path(page: 2)
    assert_response :success
    assert_equal "http://www.example.com/forum/users?page=2", canonical
    get forum_profiles_path(page: 3)
    assert_response :not_found
  end

  test "member directory: malformed page values redirect and keep the search" do
    get "/forum/users?q=ali&page=0"
    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/forum/users?q=ali"
  end

  # ---- admin member list ----

  test "admin member list: past the last page is 404, bad values redirect" do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    get admin_forum_users_path
    assert_response :success
    get admin_forum_users_path(page: 2)
    assert_response :not_found
    get admin_forum_users_path(page: "abc")
    assert_response :moved_permanently
  end
end
