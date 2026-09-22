require "test_helper"

class Admin::Forum::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin  = users(:admin)
    @member = users(:two)
    post session_path, params: { email_address: @admin.email_address, password: "password" }
  end

  test "the directory lists members" do
    get admin_forum_users_path
    assert_response :success
    assert_match @member.username, @response.body
  end

  test "search narrows by username" do
    get admin_forum_users_path, params: { q: @member.username }
    assert_response :success
    assert_match @member.username, @response.body
    assert_no_match(/#{users(:one).username}</, @response.body)
  end

  test "the banned filter shows only banned accounts" do
    get admin_forum_users_path, params: { filter: "banned" }
    assert_response :success
    assert_match users(:banned).username, @response.body
    assert_no_match(/>#{@member.username}</, @response.body)
  end

  test "banning a member signs them out and records a reason" do
    @member.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    patch admin_forum_user_path(@member), params: { decision: "ban" }
    @member.reload
    assert @member.banned?
    assert @member.ban_reason.present?
    assert_equal 0, @member.sessions.count, "an active session must not survive a ban"
  end

  test "unbanning clears the ban and its reason" do
    @member.update!(banned_at: Time.current, ban_reason: "spam")
    patch admin_forum_user_path(@member), params: { decision: "unban" }
    @member.reload
    assert_not @member.banned?
    assert_nil @member.ban_reason
  end

  test "a staff account cannot be banned from here" do
    other_admin = User.create!(email_address: "second@example.com", password: "password1",
                               username: "secondadmin", role: :admin, email_verified_at: Time.current)
    patch admin_forum_user_path(other_admin), params: { decision: "ban" }
    assert_not other_admin.reload.banned?
  end

  test "a signed-out visitor cannot reach the directory" do
    delete session_path
    get admin_forum_users_path
    assert_redirected_to root_path
  end
end
