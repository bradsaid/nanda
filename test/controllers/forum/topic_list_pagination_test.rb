require "test_helper"

class Forum::TopicListPaginationTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def make_topics(count)
    count.times do |i|
      Forum::Topic.create!(forum_category: @category, user: users(:one), title: "Paginated topic #{i}")
    end
  end

  def canonical = css_select("link[rel=canonical]").first["href"]

  test "an empty forum is a 200 with the empty state on page 1" do
    Forum::Topic.delete_all
    get forum_path
    assert_response :success
    assert_select "p", text: /No topics yet/
  end

  test "page past the end of an empty forum is a 404" do
    Forum::Topic.delete_all
    get forum_path(page: 2)
    assert_response :not_found
  end

  test "page past the last page of a populated forum is a 404" do
    Forum::Topic.delete_all
    make_topics(Forum::TopicsController::TOPICS_PER_PAGE + 1) # two pages
    get forum_path(page: 2)
    assert_response :success
    get forum_path(page: 3)
    assert_response :not_found
  end

  test "pagination is a bootstrap nav with real links and rel prev/next" do
    Forum::Topic.delete_all
    make_topics(Forum::TopicsController::TOPICS_PER_PAGE * 2 + 1) # three pages
    get forum_path(page: 2)
    assert_response :success
    assert_select "nav[aria-label=Pagination] ul.pagination li.page-item.active", text: "2"
    assert_select "a.page-link[rel=prev][href=?]", "/forum"
    assert_select "a.page-link[rel=next][href=?]", "/forum?page=3"
  end

  test "canonical is the clean URL for page 1 and ?page=N beyond it" do
    Forum::Topic.delete_all
    make_topics(Forum::TopicsController::TOPICS_PER_PAGE + 1)
    get forum_path
    assert_equal "http://www.example.com/forum", canonical
    get forum_path(page: 2)
    assert_equal "http://www.example.com/forum?page=2", canonical
    assert_equal canonical, css_select('meta[property="og:url"]').first["content"]
  end

  test "an invalid page value redirects permanently to the clean URL" do
    ["abc", "0", "-1", "1", "01", "2.5", ""].each do |bad|
      get "/forum", params: { page: bad }
      assert_response :moved_permanently, "page=#{bad.inspect} should redirect"
      assert_redirected_to "http://www.example.com/forum"
    end
  end

  test "an invalid page redirect keeps the other params" do
    get "/forum?sort=popular&page=0"
    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/forum?sort=popular"
  end

  test "an array page param redirects instead of erroring" do
    get "/forum?page[]=2"
    assert_response :moved_permanently
  end
end
