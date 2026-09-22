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

  test "deleting a member removes their post history too" do
    topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                 user: @member, title: "Goes with them")
    topic.posts.create!(user: @member, body: "also goes")

    assert_difference ["User.count", "Forum::Topic.count", "Forum::Post.count"], -1 do
      delete admin_forum_user_path(@member)
    end
    assert_not User.exists?(@member.id)
  end

  test "an admin cannot delete their own account" do
    assert_no_difference "User.count" do
      delete admin_forum_user_path(@admin)
    end
  end

  test "an admin cannot delete another admin from here" do
    other = User.create!(email_address: "other.admin@example.com", password: "password1",
                         username: "otheradmin", role: :admin, email_verified_at: Time.current)
    assert_no_difference "User.count" do
      delete admin_forum_user_path(other)
    end
  end

  test "issuing a password reset queues the email without changing the password" do
    digest_before = @member.password_digest
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post password_reset_admin_forum_user_path(@member)
    end
    assert_equal digest_before, @member.reload.password_digest
  end

  test "an episode editor can see the directory but cannot delete" do
    delete session_path
    editor = User.create!(email_address: "editor@example.com", password: "password1",
                          username: "theeditor", role: :episode_editor, email_verified_at: Time.current)
    post session_path, params: { email_address: editor.email_address, password: "password1" }

    get admin_forum_users_path
    assert_response :success
    assert_no_difference "User.count" do
      delete admin_forum_user_path(@member)
    end
  end
end
