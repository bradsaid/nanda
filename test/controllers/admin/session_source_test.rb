require "test_helper"

class Admin::SessionSourceTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "an admin who only has the remember-me cookie still reaches /admin" do
    sign_in(users(:admin))
    assert_response :redirect

    # Simulate a browser restart: the Rails session cookie is gone, the
    # 30-day signed forum_session_id cookie remains.
    token_cookie = cookies[:forum_session_id]
    reset!
    cookies[:forum_session_id] = token_cookie

    get admin_root_path
    assert_response :success
  end

  test "a banned admin is refused even with a live session" do
    sign_in(users(:admin))
    users(:admin).update_columns(banned_at: Time.current)

    get admin_root_path
    assert_redirected_to root_path
  end
end
