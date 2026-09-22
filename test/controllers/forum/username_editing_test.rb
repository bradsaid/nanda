require "test_helper"

class Forum::UsernameEditingTest < ActionDispatch::IntegrationTest
  setup do
    ENV["FORUM_ENABLED"] = "true"
    @user  = users(:one)
    @other = users(:two)
    sign_in_as(@user)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(u) = post(session_path, params: { email_address: u.email_address, password: "password" })

  def update_username(to, as_path: @user.username)
    patch forum_profile_path(username: as_path), params: { user: { username: to } }
  end

  test "the edit form offers a username field" do
    get forum_edit_profile_path(username: @user.username)
    assert_response :success
    assert_select "input[name=?]", "user[username]"
  end

  test "a member can change their own username and lands on the new address" do
    update_username("brandnewname")
    assert_equal "brandnewname", @user.reload.username
    assert_redirected_to forum_profile_path(username: "brandnewname")
  end

  test "the new name shows on their existing posts" do
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: @user, title: "Mine")
    topic.posts.create!(user: @user, body: "hello")
    update_username("renamedposter")
    get forum_topic_path(topic)
    assert_match "renamedposter", @response.body
  end

  test "a username already taken is refused, whatever the case" do
    update_username(@other.username.upcase)
    assert_not_equal @other.username.upcase, @user.reload.username
    assert_response :unprocessable_content
  end

  test "a reserved username is refused" do
    update_username("moderator")
    assert_not_equal "moderator", @user.reload.username
    assert_response :unprocessable_content
  end

  test "an invalid username is refused with a visible reason" do
    update_username("no spaces!")
    assert_not_equal "no spaces!", @user.reload.username
    assert_match(/letters, numbers/i, @response.body)
  end

  test "a member cannot rename someone else" do
    before = @other.username
    update_username("hijacked", as_path: @other.username)
    assert_equal before, @other.reload.username
  end
end
