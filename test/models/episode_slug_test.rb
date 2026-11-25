require "test_helper"

class EpisodeSlugTest < ActiveSupport::TestCase
  def series!(name) = Series.find_or_create_by!(name: name)

  def episode!(series: "Naked and Afraid", season: 14, number: 2, title: "Haunted and Hungry", **attrs)
    s = Season.find_or_create_by!(series: series!(series), number: season) { |x| x.year = 2020 }
    Episode.create!({ season: s, number_in_season: number, title: title, location: locations(:one) }.merge(attrs))
  end

  test "the slug is series + season + episode number + title" do
    assert_equal "naked-and-afraid-s14e2-haunted-and-hungry", episode!.slug
  end

  test "other series keep their name in the slug" do
    assert_equal "naked-and-afraid-xl-s4e1-the-proving-grounds", episode!(series: "Naked and Afraid XL", season: 4, number: 1, title: "The Proving Grounds").slug
    assert_equal "naked-and-afraid-last-one-standing-s2e3-last-stand", episode!(series: "Naked and Afraid: Last One Standing", season: 2, number: 3, title: "Last Stand").slug
  end

  test "episodes with the same title in different seasons and series get different slugs" do
    a = episode!(season: 1, number: 1, title: "Same Title")
    b = episode!(season: 2, number: 1, title: "Same Title")
    c = episode!(series: "Naked and Afraid XL", season: 1, number: 1, title: "Same Title")
    assert_equal 3, [a, b, c].map(&:slug).uniq.size
  end

  test "accents, quotes and punctuation are cleaned and long titles are cut at a word boundary" do
    e = episode!(title: "Côte d'Ivoire: \"Don't Look Back\" & Other Stories About Surviving The Absolutely Longest Title Ever Written")
    assert_match(/\Anaked-and-afraid-s14e2-cote-d-ivoire-don-t-look-back-other-stories/, e.slug)
    title_part = e.slug.delete_prefix("naked-and-afraid-s14e2-")
    assert_operator title_part.length, :<=, Episode::SLUG_TITLE_MAX
    assert_no_match(/-\z/, e.slug)
    assert_match(/\A[a-z0-9-]+\z/, e.slug)
  end

  test "a colliding slug gets the next free -2 suffix, not a random one" do
    first  = episode!(title: "Twin")
    # Same season/number is impossible, so force a clash on the slug itself.
    other  = episode!(season: 15, number: 1, title: "Other")
    other.update_columns(slug: "naked-and-afraid-s14e3-twin")
    third  = episode!(season: 14, number: 3, title: "Twin")
    assert_equal "naked-and-afraid-s14e3-twin-2", third.slug
    assert_equal "naked-and-afraid-s14e2-twin", first.slug
  end

  test "the slug is frozen: editing the title or number does not move the URL" do
    e = episode!
    original = e.slug
    e.update!(title: "A Different Title", number_in_season: 9)
    assert_equal original, e.reload.slug
    assert_equal original, e.to_param
  end

  test "a slug set by hand keeps the old URL resolving through history" do
    e = episode!
    old = e.slug
    e.update!(slug: "naked-and-afraid-s14e2-renamed")
    assert_equal e, Episode.friendly.find("naked-and-afraid-s14e2-renamed")
    assert_equal e, Episode.friendly.find(old)
    assert_equal e, Episode.friendly.find(e.id.to_s)
  end

  test "to_param falls back to the id while a row has no slug, and the row is still found" do
    e = episode!
    e.update_columns(slug: nil)
    assert_equal e.id.to_s, e.reload.to_param
    assert_equal e, Episode.friendly.find(e.id.to_s)
  end

  test "a row without a slug gets one the next time it is saved" do
    e = episode!
    e.update_columns(slug: nil)
    e.reload.update!(notes: "touched")
    assert_equal "naked-and-afraid-s14e2-haunted-and-hungry", e.reload.slug
  end

  test "slugs are unique at the database level" do
    a = episode!
    b = episode!(season: 20, number: 1, title: "Another")
    assert_raises(ActiveRecord::RecordNotUnique) { b.update_columns(slug: a.slug) }
  end

  test "an unknown slug is not found" do
    assert_raises(ActiveRecord::RecordNotFound) { Episode.friendly.find("no-such-episode") }
  end
end
