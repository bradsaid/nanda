require "test_helper"

class EmailVerificationConfirmTest < ActionDispatch::IntegrationTest
  setup { @user = users(:unverified) }

  test "opening the emailed link (GET) shows a button and verifies nothing" do
    token = @user.generate_token_for(:email_verification)
    get email_verification_path(token: token)
    assert_response :success
    assert_select "form[action=?][method=post]", email_verification_path(token: token)
    assert_match(/#{Regexp.escape(@user.email_address)}/, response.body)
    assert_not @user.reload.email_verified?, "a prefetching mail scanner must not verify the account"
  end

  test "pressing the button (POST) verifies the account" do
    token = @user.generate_token_for(:email_verification)
    post email_verification_path(token: token)
    assert_redirected_to new_session_path
    assert @user.reload.email_verified?
  end

  test "an invalid token is refused on both verbs" do
    get email_verification_path(token: "nope")
    assert_redirected_to root_path
    post email_verification_path(token: "nope")
    assert_redirected_to root_path
    assert_not @user.reload.email_verified?
  end

  test "a link used a second time is refused rather than shown the button again" do
    token = @user.generate_token_for(:email_verification)
    post email_verification_path(token: token)
    assert @user.reload.email_verified?

    get email_verification_path(token: token)
    assert_redirected_to root_path
    assert_match(/invalid or expired/i, flash[:alert])
  end
end
