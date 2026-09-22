require "test_helper"

class RegistrationsNotifyTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "registering queues both the verification email and the owner notice" do
    assert_enqueued_jobs 2, only: ActionMailer::MailDeliveryJob do
      post signup_path, params: { user: {
        email_address: "signup.notice@example.com", username: "noticed",
        password: "password1", password_confirmation: "password1"
      } }
    end
    assert User.exists?(email_address: "signup.notice@example.com")
  end

  test "a honeypot submission creates nothing and notifies no one" do
    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      post signup_path, params: { user: {
        email_address: "bot@example.com", username: "botaccount",
        password: "password1", password_confirmation: "password1",
        phone_number: "555-1234"
      } }
    end
    assert_not User.exists?(email_address: "bot@example.com")
  end
end
