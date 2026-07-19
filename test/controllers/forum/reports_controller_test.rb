require "test_helper"

class Forum::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @category = forum_categories(:general)
    @topic    = Forum::Topic.create!(forum_category: @category, user: users(:one), title: "Topic")
    @post     = @topic.posts.create!(user: users(:one), body: "Original post body")
  end

  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "verified user files a report and admin is emailed" do
    sign_in_as(users(:two))
    assert_emails 1 do
      assert_difference "Forum::Report.count", 1 do
        post forum_post_report_path(@post), params: {
          report: { reason: "spam", notes: "definitely spam" }
        }
      end
    end
    r = Forum::Report.order(:id).last
    assert_equal users(:two).id, r.reporter_id
    assert_equal "spam", r.reason
    assert_equal "open", r.status
  end

  test "unauthenticated visitor is redirected" do
    assert_no_difference "Forum::Report.count" do
      post forum_post_report_path(@post), params: {
        report: { reason: "spam" }
      }
    end
    assert_response :redirect
  end
end
