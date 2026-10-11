require "test_helper"

class SessionExpiryTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "a new session gets an expiry matching the cookie lifetime" do
    s = @user.sessions.create!(user_agent: "t", ip_address: "127.0.0.1")
    assert_in_delta Session::LIFETIME.from_now.to_f, s.remembered_until.to_f, 5
  end

  test "an expired session no longer authenticates" do
    s = @user.sessions.create!(user_agent: "t", ip_address: "127.0.0.1")
    assert_equal s, Session.authenticate_by_token(s.token)

    s.update_columns(remembered_until: 1.minute.ago)
    assert_nil Session.authenticate_by_token(s.token)
  end

  test "legacy rows with no expiry are honoured only within the cookie lifetime" do
    fresh = @user.sessions.create!(user_agent: "t", ip_address: "127.0.0.1")
    fresh.update_columns(remembered_until: nil)
    assert_equal fresh, Session.authenticate_by_token(fresh.token)

    stale = @user.sessions.create!(user_agent: "t", ip_address: "127.0.0.1")
    stale.update_columns(remembered_until: nil, created_at: (Session::LIFETIME + 1.day).ago)
    assert_nil Session.authenticate_by_token(stale.token)
  end

  test "changing the password revokes every session" do
    @user.sessions.create!(user_agent: "a", ip_address: "127.0.0.1")
    @user.sessions.create!(user_agent: "b", ip_address: "127.0.0.2")

    @user.update!(password: "a-new-password", password_confirmation: "a-new-password")

    assert_equal 0, @user.sessions.count
  end

  test "editing something other than the password keeps sessions" do
    @user.sessions.create!(user_agent: "a", ip_address: "127.0.0.1")

    @user.update!(bio: "Hello there")

    assert_equal 1, @user.sessions.count
  end
end
