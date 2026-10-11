require "test_helper"

class PasswordFormValidationTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:one)
    @token = @user.password_reset_token
  end

  test "a blank reset form is rejected and the old password still works" do
    patch password_path(@token), params: { password: "", password_confirmation: "" }
    assert_redirected_to edit_password_path(@token)
    assert_match(/enter a new password/i, flash[:alert])
    assert @user.reload.authenticate("password")
  end

  test "a too-short password says so rather than claiming a mismatch" do
    patch password_path(@token), params: { password: "short", password_confirmation: "short" }
    assert_redirected_to edit_password_path(@token)
    assert_match(/too short/i, flash[:alert])
    assert_no_match(/did not match/i, flash[:alert])
    assert @user.reload.authenticate("password")
  end

  test "a mismatched confirmation is reported as one" do
    patch password_path(@token), params: { password: "long-enough-1", password_confirmation: "different-1" }
    assert_redirected_to edit_password_path(@token)
    assert_match(/confirmation/i, flash[:alert])
    assert @user.reload.authenticate("password")
  end

  test "a valid reset still works" do
    patch password_path(@token), params: { password: "long-enough-1", password_confirmation: "long-enough-1" }
    assert_redirected_to new_session_path
    assert_match(/has been reset/i, flash[:notice])
    assert @user.reload.authenticate("long-enough-1")
  end

  test "the admin password form rejects a blank password" do
    admin = users(:admin)
    post session_path, params: { email_address: admin.email_address, password: "password" }
    patch admin_password_path, params: { current_password: "password", password: "", password_confirmation: "" }
    assert_response :unprocessable_entity
    assert_match(/enter a new password/i, response.body)
    assert admin.reload.authenticate("password")
  end
end
