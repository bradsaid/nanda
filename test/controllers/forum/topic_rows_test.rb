require "test_helper"

class Forum::TopicRowsTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                  user: users(:one), title: "Clickable row")
    @topic.posts.create!(user: users(:one), body: "body")
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  test "each row carries its destination so the whole row can be clicked" do
    get forum_path
    assert_response :success
    assert_select "tr.forum-clickable[data-click-href=?]", forum_topic_path(@topic)
  end

  test "the title is still a real link for keyboard and screen readers" do
    get forum_path
    assert_select "tr.forum-clickable a[href=?]", forum_topic_path(@topic), text: "Clickable row"
  end
end
