require "test_helper"

# The directory's "N unverified" total disagreed with the badge on each row:
# the total read the raw column, the badge used User#email_verified?, and
# staff accounts have a nil column while counting as verified.
class VerificationCountsTest < ActiveSupport::TestCase
  test "staff are verified whatever the column says" do
    admin = User.create!(email_address: "a@example.com", username: "anadmin",
                         password: "password1", role: :admin)
    assert_nil admin.email_verified_at
    assert admin.email_verified?
    assert_not User.unverified.exists?(admin.id), "an admin must not count as unverified"
    assert User.verified.exists?(admin.id)
  end

  test "a member who has not confirmed does count" do
    u = User.create!(email_address: "u@example.com", username: "pendingone", password: "password1")
    assert_not u.email_verified?
    assert User.unverified.exists?(u.id)
  end

  test "a member who has confirmed does not count" do
    u = User.create!(email_address: "v@example.com", username: "doneone",
                     password: "password1", email_verified_at: Time.current)
    assert_not User.unverified.exists?(u.id)
  end

  test "the scope and the predicate never disagree" do
    ids = User.unverified.pluck(:id)
    User.find_each do |u|
      assert_equal !u.email_verified?, ids.include?(u.id),
        "#{u.username.inspect} is counted differently by the scope and the predicate"
    end
  end
end
