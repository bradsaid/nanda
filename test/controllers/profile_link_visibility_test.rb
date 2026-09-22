require "test_helper"

# A signed-in member had no route to their own profile from anywhere on the
# site — the forum index mentioned their name as plain text and that was all.
class ProfileLinkVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @user = users(:one)
    post session_path, params: { email_address: @user.email_address, password: "password" }
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  test "the nav links a signed-in member to their own profile" do
    get root_path
    assert_response :success
    assert_select "nav.site-nav a[href=?]", forum_profile_path(username: @user.username)
  end

  test "the link is there on forum pages too" do
    get forum_path
    assert_select "nav.site-nav a[href=?]", forum_profile_path(username: @user.username)
  end

  test "the forum index header has a profile button beside New topic" do
    get forum_path
    assert_select ".site-header a[href=?]", forum_profile_path(username: @user.username), text: "My profile"
    assert_select ".site-header a[href=?]", new_forum_topic_path, text: "New topic"
  end

  test "the forum index offers both view and edit" do
    get forum_path
    assert_select "a[href=?]", forum_profile_path(username: @user.username)
    assert_select "a[href=?]", forum_edit_profile_path(username: @user.username), text: "Edit your profile"
  end

  test "signed-out visitors get no profile link" do
    delete session_path
    get root_path
    assert_select "nav.site-nav a[href^='/forum/users/']", count: 0
  end

  test "no profile link is offered while the forum is closed, since it would 404" do
    ENV["FORUM_ENABLED"] = nil
    get root_path
    assert_select "nav.site-nav a[href=?]", forum_profile_path(username: @user.username), count: 0
  end
end
