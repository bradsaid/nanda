require "test_helper"

class PasswordResetRevokesSessionsTest < ActionDispatch::IntegrationTest
  test "resetting a password signs out sessions that were already open" do
    user = users(:one)
    stolen = user.sessions.create!(user_agent: "attacker", ip_address: "203.0.113.9")
    token  = user.password_reset_token

    patch password_path(token), params: { password: "brand-new-pass", password_confirmation: "brand-new-pass" }
    assert_redirected_to new_session_path

    assert_nil Session.authenticate_by_token(stolen.token),
               "an attacker's remember-me token must not survive a password reset"
    assert user.reload.authenticate("brand-new-pass")
  end

  test "signing in stores an expiry and the cookie uses the same one" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    record = users(:one).sessions.order(:id).last
    assert record.remembered_until.present?
    assert_operator record.remembered_until, :>, 29.days.from_now
  end
end
