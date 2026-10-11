require "test_helper"

class SessionsReturnToTest < ActionDispatch::IntegrationTest
  def sign_in(return_to)
    post session_path, params: { email_address: users(:one).email_address,
                                 password: "password", return_to: return_to }
  end

  test "a path on this site is honoured" do
    sign_in("/episodes")
    assert_redirected_to "/episodes"
  end

  test "an off-site return_to is ignored instead of raising a 500" do
    ["https://evil.example/phish", "//evil.example", "/\\evil.example", "javascript:alert(1)"].each do |bad|
      delete session_path
      sign_in(bad)
      assert_response :redirect, "return_to=#{bad.inspect}"
      assert_equal root_url, response.location, "return_to=#{bad.inspect} should fall back to the home page"
    end
  end

  test "a bad return_to does not break a failed login either" do
    post session_path, params: { email_address: users(:one).email_address,
                                 password: "wrong", return_to: "https://evil.example" }
    assert_redirected_to new_session_path
  end

  test "the sign-in form does not carry an off-site return_to into its hidden field" do
    get new_session_path, params: { return_to: "https://evil.example" }
    assert_response :success
    assert_select "input[name=return_to]", false

    get new_session_path, params: { return_to: "/episodes" }
    assert_select "input[name=return_to][value='/episodes']"
  end
end
