require "test_helper"

class Forum::ProfileAdminControlsTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @admin  = users(:admin)
    @member = users(:two)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(u) = post(session_path, params: { email_address: u.email_address, password: "password" })

  test "an admin sees delete, ban and reset on a member's profile" do
    sign_in_as(@admin)
    get forum_profile_path(username: @member.username)
    assert_response :success
    assert_select "form[action=?]", admin_forum_user_path(@member)
    assert_select "form[action=?]", password_reset_admin_forum_user_path(@member)
    assert_match "Delete user", @response.body
  end

  test "an admin sees no delete control on their own profile" do
    sign_in_as(@admin)
    get forum_profile_path(username: @admin.username)
    assert_no_match(/Delete user/, @response.body)
  end

  test "an ordinary member sees none of it, on anyone" do
    sign_in_as(users(:one))
    get forum_profile_path(username: @member.username)
    assert_no_match(/Delete user/, @response.body)
    assert_no_match(/Ban</, @response.body)
  end

  test "an episode editor does not get the delete control" do
    editor = User.create!(email_address: "ed@example.com", password: "password1",
                          username: "edmember", role: :episode_editor, email_verified_at: Time.current)
    post session_path, params: { email_address: editor.email_address, password: "password1" }
    get forum_profile_path(username: @member.username)
    assert_no_match(/Delete user/, @response.body)
  end

  test "the nav offers Admin to staff and nobody else" do
    sign_in_as(@admin)
    get root_path
    assert_select "nav.site-nav a[href=?]", admin_root_path, text: "Admin"

    sign_in_as(users(:one))
    get root_path
    assert_select "nav.site-nav a[href=?]", admin_root_path, count: 0

    delete session_path
    get root_path
    assert_select "nav.site-nav a[href=?]", admin_root_path, count: 0
  end
end
