require "test_helper"

class UsernameUniquenessTest < ActiveSupport::TestCase
  setup do
    @taken = User.create!(email_address: "taken@example.com", username: "Cassius",
                          password: "password1")
  end

  test "the same username is refused" do
    dupe = User.new(email_address: "a@example.com", username: "Cassius", password: "password1")
    assert_not dupe.valid?
    assert_includes dupe.errors[:username].join, "taken"
  end

  test "a username differing only by case is refused" do
    %w[cassius CASSIUS cAsSiUs].each do |variant|
      dupe = User.new(email_address: "#{variant}@example.com", username: variant, password: "password1")
      assert_not dupe.valid?, "#{variant} should collide with Cassius"
    end
  end

  # Validation can lose a race between two simultaneous signups; the database
  # is the only thing that cannot.
  test "the database refuses a case variant even when validation is skipped" do
    sneaky = User.new(email_address: "sneaky@example.com", username: "ALICE", password: "password1")
    assert_raises(ActiveRecord::RecordNotUnique) { sneaky.save!(validate: false) }
  end

  test "usernames keep the capitalisation their owner chose" do
    assert_equal "Cassius", @taken.reload.username
  end

  test "several members may have no username without colliding" do
    2.times { |i| User.create!(email_address: "nouser#{i}@example.com", password: "password1") }
    assert_equal 2, User.where(username: nil).count
  end
end
