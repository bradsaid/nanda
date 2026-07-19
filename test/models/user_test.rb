require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @attrs = {
      email_address: "new@example.com",
      username:      "newperson",
      password:      "password123",
      password_confirmation: "password123"
    }
  end

  test "creates a valid user" do
    u = User.new(@attrs)
    assert u.valid?, u.errors.full_messages.to_sentence
  end

  test "requires email" do
    u = User.new(@attrs.merge(email_address: nil))
    assert_not u.valid?
    assert u.errors[:email_address].any?
  end

  test "downcases email on save" do
    u = User.create!(@attrs.merge(email_address: "MIXED@Example.COM"))
    assert_equal "mixed@example.com", u.email_address
  end

  test "rejects duplicate email" do
    User.create!(@attrs)
    dup = User.new(@attrs.merge(username: "someone_else"))
    assert_not dup.valid?
    assert dup.errors[:email_address].any?
  end

  test "rejects short username" do
    u = User.new(@attrs.merge(username: "ab"))
    assert_not u.valid?
    assert u.errors[:username].any?
  end

  test "rejects username with punctuation" do
    u = User.new(@attrs.merge(username: "bad-name"))
    assert_not u.valid?
    assert u.errors[:username].any?
  end

  test "rejects reserved username for non-admin" do
    u = User.new(@attrs.merge(username: "admin"))
    assert_not u.valid?
    assert u.errors[:username].any?
  end

  test "allows reserved username for admin role" do
    u = User.new(@attrs.merge(username: "admin", role: :admin))
    assert u.valid?, u.errors.full_messages.to_sentence
  end

  test "requires min 8-char password on create" do
    u = User.new(@attrs.merge(password: "short", password_confirmation: "short"))
    assert_not u.valid?
    assert u.errors[:password].any?
  end

  test "email_verified? reflects timestamp" do
    u = User.new(@attrs)
    assert_not u.email_verified?
    u.email_verified_at = Time.current
    assert u.email_verified?
  end

  test "banned? reflects banned_at" do
    u = User.new(@attrs)
    assert_not u.banned?
    u.banned_at = Time.current
    assert u.banned?
  end

  test "generates_token_for :email_verification round-trips" do
    u = User.create!(@attrs)
    token = u.generate_token_for(:email_verification)
    found = User.find_by_token_for(:email_verification, token)
    assert_equal u.id, found.id
  end

  test "email verification token invalidates once verified" do
    u = User.create!(@attrs)
    token = u.generate_token_for(:email_verification)
    u.update!(email_verified_at: Time.current)
    assert_nil User.find_by_token_for(:email_verification, token)
  end
end
