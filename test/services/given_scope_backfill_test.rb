require "test_helper"
require "rake"

class GivenScopeBackfillTest < ActiveSupport::TestCase
  setup do
    @pot  = Item.create!(name: "backfill pot")
    @hide = Item.create!(name: "backfill hide")
  end

  # Given rows as they are in production before the backfill: no scope.
  def legacy_give(item, appearances, quantity: 1, subtype: nil)
    give(item, appearances, quantity: quantity, subtype: subtype).each { |ai| ai.update_columns(given_scope: nil) }
  end

  # The fixtures hold a given row of their own; only look at this test's items.
  def backfill_for(*items)
    GivenScopeBackfill.new(AppearanceItem.given.where(given_scope: nil, item_id: items.map(&:id))).classify
  end

  def decision_for(backfill, item, episode)
    backfill.groups.find { |g| g.item_id == item.id && g.episode_id == episode.id }
  end

  test "an item on every survivor with quantity 1 is a team item" do
    ep, apps = build_episode_with_survivors(3)
    legacy_give(@pot, apps)
    g = decision_for(GivenScopeBackfill.new.classify, @pot, ep)
    assert_equal "team", g.scope
    assert_not g.review
  end

  test "a solo episode is team, with nothing to review" do
    ep, apps = build_episode_with_survivors(1)
    legacy_give(@pot, apps, quantity: 2)
    g = decision_for(GivenScopeBackfill.new.classify, @pot, ep)
    assert_equal "team", g.scope
    assert_not g.review
  end

  test "an item on only some survivors stays individual and is flagged for review" do
    ep, (a1, a2, _a3) = build_episode_with_survivors(3)
    legacy_give(@pot, [a1, a2])
    g = decision_for(GivenScopeBackfill.new.classify, @pot, ep)
    assert_equal "individual", g.scope
    assert g.review
  end

  test "an item on one of two survivors is flagged; one of three is just that survivor's own item" do
    ep2, (a1, _a2) = build_episode_with_survivors(2)
    ep3, (b1, _b2, _b3) = build_episode_with_survivors(3)
    legacy_give(@pot, [a1])
    legacy_give(@pot, [b1])
    backfill = GivenScopeBackfill.new.classify
    assert_equal "individual", decision_for(backfill, @pot, ep2).scope
    assert decision_for(backfill, @pot, ep2).review
    assert_equal "individual", decision_for(backfill, @pot, ep3).scope
    assert_not decision_for(backfill, @pot, ep3).review
  end

  test "quantity above one on every survivor is individual and flagged" do
    ep, apps = build_episode_with_survivors(2)
    legacy_give(@pot, apps, quantity: 2)
    g = decision_for(GivenScopeBackfill.new.classify, @pot, ep)
    assert_equal "individual", g.scope
    assert g.review
  end

  test "each item and subtype in an episode is decided on its own" do
    ep, (a1, a2) = build_episode_with_survivors(2)
    legacy_give(@pot, [a1, a2])
    legacy_give(@hide, [a1], subtype: "elk")
    backfill = backfill_for(@pot, @hide)
    assert_equal 2, backfill.groups.size
    assert_equal "team",       decision_for(backfill, @pot, ep).scope
    assert_equal "individual", decision_for(backfill, @hide, ep).scope
  end

  test "classify only reads: nothing is written until apply!" do
    _, apps = build_episode_with_survivors(2)
    legacy_give(@pot, apps)
    GivenScopeBackfill.new.classify
    assert_equal [nil], AppearanceItem.where(item: @pot).pluck(:given_scope).uniq
  end

  test "apply! writes every row, bumps updated_at for the page caches, and is idempotent" do
    ep, apps = build_episode_with_survivors(2)
    legacy_give(@pot, apps)
    AppearanceItem.where(item: @pot).update_all(updated_at: 1.year.ago)

    GivenScopeBackfill.new.apply!
    assert_equal ["team"], AppearanceItem.where(item: @pot).pluck(:given_scope).uniq
    assert AppearanceItem.where(item: @pot).all? { |ai| ai.updated_at > 1.minute.ago }

    assert_empty GivenScopeBackfill.new.classify.groups, "a second run finds nothing left to do"
  end

  test "rows that already have a scope are never overwritten" do
    ep, apps = build_episode_with_survivors(2)
    give(@pot, apps, scope: "individual") # chosen by hand; would look like a team item to the heuristic
    GivenScopeBackfill.new.apply!
    assert_equal ["individual"], AppearanceItem.where(item: @pot).pluck(:given_scope).uniq
  end

  test "the backfill makes the counts right" do
    _, apps = build_episode_with_survivors(3)
    legacy_give(@pot, apps)
    assert_equal 3, AppearanceItem.where(item: @pot).given_count, "before: counted per row"
    GivenScopeBackfill.new.apply!
    assert_equal 1, AppearanceItem.where(item: @pot).given_count, "after: one team pot"
  end

  test "totals and the by-type summary cover what would change" do
    _, apps = build_episode_with_survivors(2, arrangement: "2+2")
    legacy_give(@pot, apps)
    backfill = backfill_for(@pot)
    t = backfill.totals
    # two survivors, "2+2" says two teams: raw rows 2, once per episode 1, once per team 2
    assert_equal [2, 1, 2, 1, 2], [t[:rows], t[:groups], t[:units_before], t[:units_once_per_episode], t[:units_after]]
    assert_equal 1, backfill.summary_by_type.fetch("2+2")[:team]
  end

  # ----- the rake task -----

  def run_task(env = {})
    Rake.application.rake_require("tasks/appearance_items", [Rails.root.join("lib").to_s]) unless Rake::Task.task_defined?("appearance_items:backfill_given_scope")
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    task = Rake::Task["appearance_items:backfill_given_scope"]
    task.reenable
    old = env.keys.to_h { |k| [k, ENV[k]] }
    env.each { |k, v| ENV[k] = v }
    out, = capture_io { task.invoke }
    out
  ensure
    old&.each { |k, v| ENV[k] = v }
  end

  test "the rake task is a dry run by default and writes with WRITE=1" do
    _, apps = build_episode_with_survivors(2)
    legacy_give(@pot, apps)

    out = run_task("WRITE" => nil)
    assert_match(/DRY RUN/, out)
    assert_equal [nil], AppearanceItem.where(item: @pot).pluck(:given_scope).uniq

    out = run_task("WRITE" => "1")
    assert_match(/WRITE/, out)
    assert_equal ["team"], AppearanceItem.where(item: @pot).pluck(:given_scope).uniq
  end
end

class GivenScopeBackfillPerTeamTest < ActiveSupport::TestCase
  setup do
    @pot = Item.create!(name: "perteam pot")
  end

  def legacy_give(item, appearances, quantity: 1)
    give(item, appearances, quantity: quantity).each { |ai| ai.update_columns(given_scope: nil) }
  end

  def backfill_for(*items)
    GivenScopeBackfill.new(AppearanceItem.given.where(given_scope: nil, item_id: items.map(&:id))).classify
  end

  def group(backfill, ep) = backfill.groups.find { |g| g.episode_id == ep.id }

  test "totals show raw rows, once per episode and once per team" do
    ep, apps = build_episode_with_survivors(12, arrangement: "3+3+3+3")
    legacy_give(@pot, apps)
    t = backfill_for(@pot).totals
    assert_equal [12, 1, 4], [t[:units_before], t[:units_once_per_episode], t[:units_after]]
  end

  test "counted totals match what the rule counts after the backfill is written" do
    ep, apps = build_episode_with_survivors(5, arrangement: "3+2")
    legacy_give(@pot, apps)
    predicted = backfill_for(@pot).totals[:units_after]
    GivenScopeBackfill.new(AppearanceItem.given.where(given_scope: nil, item_id: @pot.id)).apply!
    assert_equal predicted, AppearanceItem.where(item: @pot).given_count
    assert_equal 2, predicted
  end

  test "an item on only some survivors of a multi-team episode is flagged, even one survivor" do
    ep, apps = build_episode_with_survivors(5, arrangement: "3+2")
    legacy_give(@pot, apps.first(1))
    g = group(backfill_for(@pot), ep)
    assert_equal "individual", g.scope
    assert g.review
    assert_match(/each of the 2 teams should have got it/, g.reason)
  end

  test "the same single-recipient item in a one-team episode is not flagged" do
    ep, apps = build_episode_with_survivors(3, arrangement: "Standard")
    legacy_give(@pot, apps.first(1))
    assert_not group(backfill_for(@pot), ep).review
  end

  test "a team item on every survivor of a multi-team episode is team and not flagged" do
    ep, apps = build_episode_with_survivors(5, arrangement: "3+2")
    legacy_give(@pot, apps)
    g = group(backfill_for(@pot), ep)
    assert_equal ["team", false, 2], [g.scope, g.review, g.teams]
  end

  test "more teams than survivors is flagged because the count is capped" do
    ep, apps = build_episode_with_survivors(2, arrangement: "3+3+3+3")
    legacy_give(@pot, apps)
    g = group(backfill_for(@pot), ep)
    assert g.review
    assert_match(/counted 2/, g.reason)
    assert_equal 2, g.counted_units
  end

  test "episodes with 2+ survivors and an unparseable arrangement are listed; known ones are not" do
    unknown, a1 = build_episode_with_survivors(2, arrangement: "Group")
    blank, a2   = build_episode_with_survivors(2, arrangement: nil)
    known, a3   = build_episode_with_survivors(2, arrangement: "Standard")
    parsed, a4  = build_episode_with_survivors(5, arrangement: "3+2")
    one, a5     = build_episode_with_survivors(1, arrangement: "Group")
    [a1, a2, a3, a4, a5].each { |apps| legacy_give(@pot, apps) }
    listed = backfill_for(@pot).unparseable_arrangement_episodes.map(&:id)
    assert_equal [unknown.id, blank.id].sort, listed.sort
  end

  test "the by-type summary carries the teams and the counted total" do
    ep, apps = build_episode_with_survivors(12, arrangement: "3+3+3+3")
    legacy_give(@pot, apps)
    row = backfill_for(@pot).summary_by_type.fetch("3+3+3+3")
    assert_equal [4, 4], [row[:teams], row[:counted]]
  end

  test "the rake dry run prints the per-team totals and the unparseable list, and saves nothing" do
    ep, apps = build_episode_with_survivors(5, arrangement: "3+2")
    legacy_give(@pot, apps)
    odd, odd_apps = build_episode_with_survivors(2, arrangement: "Group", title: "Odd Arrangement Ep")
    legacy_give(@pot, odd_apps)
    Rake.application.rake_require("tasks/appearance_items", [Rails.root.join("lib").to_s]) unless Rake::Task.task_defined?("appearance_items:backfill_given_scope")
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    task = Rake::Task["appearance_items:backfill_given_scope"]
    task.reenable
    old = ENV.delete("WRITE")
    out, = capture_io { task.invoke }
    ENV["WRITE"] = old if old

    assert_match(/DRY RUN/, out)
    assert_match(/once per TEAM/, out)
    assert_match(/once per episode/, out)
    assert_match(/Per item/, out)
    assert_match(/perteam pot/, out)
    assert_match(/Odd Arrangement Ep/, out)
    assert_equal [nil], AppearanceItem.where(item: @pot).pluck(:given_scope).uniq
  end
end
