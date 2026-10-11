require "test_helper"

class Forum::TopicAndReportTest < ActiveSupport::TestCase
  setup do
    @category = forum_categories(:general)
    @topic = Forum::Topic.create!(forum_category: @category, user: users(:one), title: "Topic")
    @post  = @topic.posts.create!(user: users(:one), body: "Body")
  end

  test "a topic titled 'New' does not take the new-topic route's slug" do
    t = Forum::Topic.create!(forum_category: @category, user: users(:one), title: "New")
    assert_not_equal "new", t.slug
    assert_equal "new-topic", t.slug
    assert_equal t, Forum::Topic.friendly.find(t.slug)
  end

  test "a topic titled 'Edit' is also kept off the route word" do
    t = Forum::Topic.create!(forum_category: @category, user: users(:one), title: "Edit")
    assert_equal "edit-topic", t.slug
  end

  test "an ordinary title keeps its plain slug" do
    t = Forum::Topic.create!(forum_category: @category, user: users(:one), title: "Season finale chat")
    assert_equal "season-finale-chat", t.slug
  end

  test "an unknown report reason is a validation error, not an exception" do
    report = Forum::Report.new(reporter: users(:two), reportable: @post, reason: "nonsense", status: "open")
    assert_nothing_raised { report.valid? }
    assert_not report.valid?
    assert report.errors[:reason].any?
  end

  test "the same member cannot file a second open report on the same post" do
    Forum::Report.create!(reporter: users(:two), reportable: @post, reason: "spam", status: "open")
    dup = Forum::Report.new(reporter: users(:two), reportable: @post, reason: "abuse", status: "open")
    assert_not dup.valid?
    assert_match(/already reported/i, dup.errors.full_messages.to_sentence)
  end

  test "a different member, or the same member after review, may report again" do
    first = Forum::Report.create!(reporter: users(:two), reportable: @post, reason: "spam", status: "open")
    assert Forum::Report.new(reporter: users(:admin), reportable: @post, reason: "spam", status: "open").valid?

    first.update!(status: "dismissed")
    assert Forum::Report.new(reporter: users(:two), reportable: @post, reason: "spam", status: "open").valid?
  end
end
