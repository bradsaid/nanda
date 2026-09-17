require "test_helper"

class AuthVisibilityTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  teardown { ENV["FORUM_ENABLED"] = nil }

  # Accounts are deliberately not advertised until the forum opens: site email
  # cannot yet send from a real domain address, so a signup would hand out a
  # verification link that never arrives.
  test "no account links while the forum is closed" do
    ENV["FORUM_ENABLED"] = nil
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_session_path, count: 0
    assert_select "a[href=?]", signup_path,      count: 0
  end

  test "opening the forum reveals sign in and sign up together" do
    ENV["FORUM_ENABLED"] = "true"
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_session_path, text: "Sign in"
    assert_select "a[href=?]", signup_path,      text: "Sign up"
  end

  test "signup page still answers directly for anyone holding the URL" do
    get signup_path
    assert_response :success
  end

  # Verification mail used to be deliver_now inside a 5s timeout that swallowed
  # failures — a slow SMTP server made signup feel broken or dropped the link.
  test "the verification email is queued, not sent inside the request" do
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post signup_path, params: { user: {
        email_address: "brand.new@example.com", username: "brandnew",
        password: "password1", password_confirmation: "password1"
      } }
    end
    assert User.exists?(email_address: "brand.new@example.com")
  end
end
