require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "GET /signup renders" do
    get signup_path
    assert_response :success
    assert_select "form"
  end

  test "creates a user and sends verification email" do
    assert_emails 1 do
      assert_difference "User.count", 1 do
        post signup_path, params: {
          user: { email_address: "new@example.com", username: "newperson",
                  password: "passphrase1", password_confirmation: "passphrase1" }
        }
      end
    end
    assert_redirected_to new_session_path
    user = User.find_by(email_address: "new@example.com")
    assert user.present?
    assert_nil user.email_verified_at
  end

  test "honeypot silently rejects" do
    assert_no_difference "User.count" do
      post signup_path, params: {
        user: { email_address: "spam@example.com", username: "spammer",
                password: "passphrase1", password_confirmation: "passphrase1",
                phone_number: "555-1234" }
      }
    end
    assert_redirected_to root_path
  end

  test "duplicate email is rejected" do
    User.create!(email_address: "dup@example.com", username: "dupfirst",
                 password: "passphrase1", password_confirmation: "passphrase1")
    assert_no_difference "User.count" do
      post signup_path, params: {
        user: { email_address: "dup@example.com", username: "dupsecond",
                password: "passphrase1", password_confirmation: "passphrase1" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "SIGNUPS_DISABLED env killswitch blocks create" do
    original = ENV["SIGNUPS_DISABLED"]
    ENV["SIGNUPS_DISABLED"] = "1"
    assert_no_difference "User.count" do
      post signup_path, params: {
        user: { email_address: "blocked@example.com", username: "blocked",
                password: "passphrase1", password_confirmation: "passphrase1" }
      }
    end
    assert_redirected_to root_path
  ensure
    ENV["SIGNUPS_DISABLED"] = original
  end
end
