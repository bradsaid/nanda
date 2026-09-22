require "test_helper"

class Admin::Forum::UserActionsVisibleTest < ActionDispatch::IntegrationTest
  setup do
    @admin  = users(:admin)
    @member = users(:two)
    post session_path, params: { email_address: @admin.email_address, password: "password" }
  end

  test "a full admin is shown delete and reset controls for a member" do
    get admin_forum_users_path
    assert_response :success
    assert_select "form[action=?]", admin_forum_user_path(@member)
    assert_select "form[action=?]", password_reset_admin_forum_user_path(@member)
    assert_match "Delete", @response.body
    assert_match "Reset password", @response.body
  end

  test "no delete control is offered for the admin's own row" do
    get admin_forum_users_path
    assert_select "form[action=?]", admin_forum_user_path(@admin), count: 0
  end

  test "the actions column is labelled so it can be found" do
    get admin_forum_users_path
    assert_select "th", text: "Actions"
  end
end
