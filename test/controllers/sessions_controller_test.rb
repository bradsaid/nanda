require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /session/new renders" do
    get new_session_path
    assert_response :success
  end

  test "valid credentials sign in and set session[:user_id]" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    assert_response :redirect
    assert_equal users(:one).id, session[:user_id]
  end

  test "invalid credentials redirect back with alert" do
    post session_path, params: { email_address: users(:one).email_address, password: "wrong" }
    assert_redirected_to new_session_path(return_to: nil)
    assert_nil session[:user_id]
  end

  test "banned user cannot sign in" do
    post session_path, params: { email_address: users(:banned).email_address, password: "password" }
    assert_redirected_to new_session_path
    assert_nil session[:user_id]
  end

  test "logout clears session and cookie" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    delete session_path
    assert_response :redirect
    assert_nil session[:user_id]
  end
end
