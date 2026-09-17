require "test_helper"

class AuthVisibilityTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Sign in / Sign up used to be hidden unless FORUM_ENABLED was set, so there
  # was no link to an account from anywhere on the site.
  test "signed-out visitors are offered sign in and sign up, forum flag or not" do
    ENV["FORUM_ENABLED"] = nil
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_session_path, text: "Sign in"
    assert_select "a[href=?]", signup_path,      text: "Sign up"
  end

  test "signup page is reachable" do
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
