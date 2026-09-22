require "test_helper"

class ForumPromoTest < ActionDispatch::IntegrationTest
  setup { ENV["FORUM_ENABLED"] = "true" }
  teardown { ENV["FORUM_ENABLED"] = nil }

  test "it appears on wiki pages" do
    get root_path
    assert_response :success
    assert_select ".forum-promo"
    assert_select ".forum-promo a[href=?]", forum_path
  end

  test "signed-out readers are also offered an account" do
    get root_path
    assert_select ".forum-promo a[href=?]", signup_path
  end

  test "signed-in members are not asked to sign up again" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    get root_path
    assert_select ".forum-promo"
    assert_select ".forum-promo a[href=?]", signup_path, count: 0
  end

  test "it does not appear on the forum, where they already are" do
    get forum_path
    assert_select ".forum-promo", count: 0
  end

  test "it does not appear on sign-in or signup" do
    get new_session_path
    assert_select ".forum-promo", count: 0
    get signup_path
    assert_select ".forum-promo", count: 0
  end

  test "dismissing it keeps it dismissed" do
    get root_path
    assert_select ".forum-promo"
    cookies[:forum_promo_dismissed] = "1"
    get root_path
    assert_select ".forum-promo", count: 0
  end

  test "it stays hidden while the forum is closed" do
    ENV["FORUM_ENABLED"] = nil
    get root_path
    assert_select ".forum-promo", count: 0
  end
end
