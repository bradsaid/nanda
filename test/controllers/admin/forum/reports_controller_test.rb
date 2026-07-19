require "test_helper"

class Admin::Forum::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
    @topic    = Forum::Topic.create!(forum_category: @category, user: users(:one), title: "Topic")
    @post     = @topic.posts.create!(user: users(:one), body: "Body")
    @report   = Forum::Report.create!(
      reporter:   users(:two),
      reportable: @post,
      reason:     "spam",
      status:     "open"
    )
  end

  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "non-admin cannot access" do
    sign_in_as(users(:one))
    get admin_forum_reports_path
    assert_response :redirect
  end

  test "admin sees the queue" do
    sign_in_as(users(:admin))
    get admin_forum_reports_path
    assert_response :success
  end

  test "admin can dismiss a report" do
    sign_in_as(users(:admin))
    patch admin_forum_report_path(@report), params: { decision: "dismiss" }
    assert_response :redirect
    assert_equal "dismissed", @report.reload.status
    assert_equal users(:admin).id, @report.handled_by_id
  end

  test "admin can remove reported post" do
    sign_in_as(users(:admin))
    patch admin_forum_report_path(@report), params: { decision: "remove_post" }
    assert_response :redirect
    assert @post.reload.deleted_at.present?
    assert_equal "actioned", @report.reload.status
  end

  test "admin can ban the offending user" do
    sign_in_as(users(:admin))
    patch admin_forum_report_path(@report), params: { decision: "ban_user", ban_reason: "spam" }
    assert_response :redirect
    assert users(:one).reload.banned?
    assert_equal "spam", users(:one).reload.ban_reason
  end
end
