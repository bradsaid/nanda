require "test_helper"

class EmailChangeTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ENV["FORUM_ENABLED"] = "true"
    @user  = users(:one)
    @other = users(:two)
    sign_in_as(@user)
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(u) = post(session_path, params: { email_address: u.email_address, password: "password" })

  def request_change(to:, password: "password", as: @user)
    post forum_request_email_change_path(username: as.username),
         params: { new_email_address: to, current_password: password }
  end

  test "requesting a change does not touch the current address" do
    original = @user.email_address
    request_change(to: "new.address@example.com")
    @user.reload
    assert_equal original, @user.email_address, "the live address must not move yet"
    assert_equal "new.address@example.com", @user.pending_email_address
  end

  test "it emails both the new address and the old one" do
    assert_enqueued_jobs 2, only: ActionMailer::MailDeliveryJob do
      request_change(to: "new.address@example.com")
    end
  end

  test "the wrong password changes nothing" do
    request_change(to: "new.address@example.com", password: "not-my-password")
    assert_nil @user.reload.pending_email_address
  end

  test "confirming from the link applies the change and marks it verified" do
    request_change(to: "confirmed@example.com")
    token = @user.reload.generate_token_for(:email_change)

    get email_change_path(token: token)
    @user.reload
    assert_equal "confirmed@example.com", @user.email_address
    assert_nil @user.pending_email_address
    assert @user.email_verified_at.present?
  end

  test "the new address can then be used to sign in" do
    request_change(to: "movedto@example.com")
    get email_change_path(token: @user.reload.generate_token_for(:email_change))
    delete session_path
    post session_path, params: { email_address: "MovedTo@Example.com", password: "password" }
    assert_redirected_to root_path
  end

  test "an address already in use is refused" do
    request_change(to: @other.email_address)
    assert_nil @user.reload.pending_email_address
  end

  test "an address claimed by someone else before confirmation is refused at the link" do
    request_change(to: "contested@example.com")
    token = @user.reload.generate_token_for(:email_change)
    User.create!(email_address: "contested@example.com", username: "claimant", password: "password1")

    get email_change_path(token: token)
    @user.reload
    assert_not_equal "contested@example.com", @user.email_address
    assert_nil @user.pending_email_address
  end

  test "a tampered token does nothing" do
    request_change(to: "nope@example.com")
    get email_change_path(token: "not-a-real-token")
    assert_equal users(:one).email_address, @user.reload.email_address
  end

  test "cancelling clears the pending address" do
    request_change(to: "cancelme@example.com")
    delete forum_cancel_email_change_path(username: @user.username)
    assert_nil @user.reload.pending_email_address
  end

  test "nobody can move another member's address, admin included" do
    sign_in_as(users(:admin))
    request_change(to: "stolen@example.com", as: @user)
    assert_nil @user.reload.pending_email_address
  end
end
