require "test_helper"

class Forum::MemberDirectoryTest < ActionDispatch::IntegrationTest
  setup { ENV["FORUM_ENABLED"] = "true" }
  teardown { ENV["FORUM_ENABLED"] = nil }

  test "anyone can see the directory, signed in or not" do
    get forum_profiles_path
    assert_response :success
    assert_select "a[href=?]", forum_profile_path(username: users(:one).username)
  end

  test "the forum index links to it" do
    get forum_path
    assert_select "a[href=?]", forum_profiles_path, text: "Members"
  end

  test "the whole member card is a click target" do
    get forum_profiles_path
    assert_select ".card.forum-clickable[data-click-href=?]",
      forum_profile_path(username: users(:one).username)
  end

  test "the username inside stays a real link for keyboard users" do
    get forum_profiles_path
    assert_select ".card.forum-clickable a[href=?]",
      forum_profile_path(username: users(:one).username)
  end

  test "banned members are hidden" do
    get forum_profiles_path
    assert_no_match(/#{users(:banned).username}/, @response.body)
  end

  test "no email address is exposed" do
    get forum_profiles_path
    User.find_each { |u| assert_no_match(/#{Regexp.escape(u.email_address)}/, @response.body) }
  end

  test "search narrows the list" do
    get forum_profiles_path, params: { q: users(:one).username }
    assert_match users(:one).username, @response.body
    assert_no_match(/>#{users(:two).username}</, @response.body)
  end
end
