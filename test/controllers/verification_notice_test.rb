require "test_helper"

# Two thirds of the forum's members had signed up but never confirmed their
# address, which silently blocks posting. The only hint was one muted line at
# the foot of the forum list, and nothing offered to resend the email.
class VerificationNoticeTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ENV["FORUM_ENABLED"] = "true"
    @pending  = users(:unverified)
    @verified = users(:one)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(u) = post(session_path, params: { email_address: u.email_address, password: "password" })

  test "an unverified member is told plainly, with their address" do
    sign_in_as(@pending)
    get forum_path
    assert_response :success
    assert_match(/confirm your email address/i, @response.body)
    assert_match @pending.email_address, @response.body
  end

  test "the notice follows them around the site, not just the forum" do
    sign_in_as(@pending)
    get root_path
    assert_match(/confirm your email address/i, @response.body)
  end

  test "a verified member never sees it" do
    sign_in_as(@verified)
    get forum_path
    assert_no_match(/confirm your email address to post/i, @response.body)
  end

  test "a signed-out visitor never sees it" do
    get root_path
    assert_no_match(/confirm your email address to post/i, @response.body)
  end

  test "staff are exempt, since their accounts skip the email flow" do
    sign_in_as(users(:admin))
    get root_path
    assert_no_match(/confirm your email address to post/i, @response.body)
  end

  test "the resend button actually sends, without retyping the address" do
    sign_in_as(@pending)
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post resend_email_verification_path
    end
  end

  test "resending returns you to the page you were on" do
    sign_in_as(@pending)
    get forum_path
    post resend_email_verification_path, headers: { "HTTP_REFERER" => forum_url }
    assert_redirected_to forum_url
    assert_match(/sent to #{Regexp.escape(@pending.email_address)}/i, flash[:notice])
  end

  test "an already-verified member resending sends nothing" do
    sign_in_as(@verified)
    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      post resend_email_verification_path
    end
  end

  test "a signed-out resend still reveals nothing about who has an account" do
    post resend_email_verification_path, params: { email_address: "nobody@example.com" }
    assert_match(/if that account exists/i, flash[:notice])
  end

  test "the reply hint offers the resend too" do
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: @verified, title: "A topic")
    topic.posts.create!(user: @verified, body: "hi")
    sign_in_as(@pending)
    get forum_topic_path(topic)
    assert_select "form[action=?]", resend_email_verification_path
  end
end
