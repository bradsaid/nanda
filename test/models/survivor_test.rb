require "test_helper"

class SurvivorTest < ActiveSupport::TestCase
  test "a renamed survivor is still found by the old slug" do
    s = Survivor.create!(full_name: "Cass Caddidy")
    old_slug = s.slug

    s.update!(full_name: "Cass Cassidy")

    assert_not_equal old_slug, s.slug
    assert_equal s, Survivor.friendly.find(s.slug)
    assert_equal s, Survivor.friendly.find(old_slug), "the pre-rename URL must keep resolving"
  end

  test "deleting a survivor keeps their medical calls on the episode" do
    s    = Survivor.create!(full_name: "Medical Case")
    call = MedicalCall.create!(episode: episodes(:one), survivor: s, reason: "dehydration", led_to_tapout: true)

    assert_nothing_raised { s.destroy! }

    call.reload
    assert_nil call.survivor_id
    assert_equal "dehydration", call.reason
    assert call.led_to_tapout
  end
end
