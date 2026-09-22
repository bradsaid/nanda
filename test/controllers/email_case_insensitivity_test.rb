require "test_helper"

# A member typing their own address with different capitalisation could not
# sign in and could not reset their password — the reset page even told them
# the email had been sent.
class EmailCaseInsensitivityTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email_address: "erin.example@gmail.com", username: "erinx",
                         password: "password1", email_verified_at: Time.current)
    @shouty = "Erin.Example@Gmail.com"
  end

  test "sign in works whatever case the address is typed in" do
    post session_path, params: { email_address: @shouty, password: "password1" }
    assert_redirected_to root_path
    follow_redirect!
    assert_no_match(/Try another email address or password/, @response.body)
  end

  test "a password reset actually sends when the address is typed in another case" do
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post passwords_path, params: { email_address: @shouty }
    end
  end

  test "surrounding whitespace does not break the lookup" do
    assert_equal @user, User.find_by_email("  ERIN.EXAMPLE@GMAIL.COM  ")
  end

  test "a reset for an address nobody owns still enqueues nothing" do
    assert_no_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      post passwords_path, params: { email_address: "nobody@example.com" }
    end
  end

  test "a second account cannot be registered on the same address in another case" do
    dupe = User.new(email_address: "ERIN.EXAMPLE@gmail.com", username: "erincopy",
                    password: "password1")
    assert_not dupe.valid?, "uniqueness must ignore case"
    assert_includes dupe.errors[:email_address].join, "taken"
  end

  test "the stored address is normalised on the way in" do
    u = User.create!(email_address: "  MiXeD@Example.COM ", username: "mixedcase",
                     password: "password1")
    assert_equal "mixed@example.com", u.reload.email_address
  end
end
