require "test_helper"

class AppearanceItemTest < ActiveSupport::TestCase
  setup do
    @pot  = Item.create!(name: "scope pot")
    @hide = Item.create!(name: "scope hide")
  end

  # ----- given_scope: defaults and validation -----

  test "a new given item defaults to team" do
    a = build_episode_with_survivors(1).last.first
    ai = AppearanceItem.create!(appearance: a, item: @pot, source: "given")
    assert_equal "team", ai.given_scope
    assert ai.given_to_team?
  end

  test "an explicit individual scope is kept" do
    a = build_episode_with_survivors(1).last.first
    ai = AppearanceItem.create!(appearance: a, item: @pot, source: "given", given_scope: "individual")
    assert_equal "individual", ai.reload.given_scope
    assert_not ai.given_to_team?
  end

  test "brought and found items have no scope" do
    a = build_episode_with_survivors(1).last.first
    %w[brought found].each_with_index do |source, i|
      ai = AppearanceItem.create!(appearance: a, item: Item.create!(name: "scope #{source}"), source: source, given_scope: "")
      assert_nil ai.reload.given_scope, "#{source} rows carry no scope"
    end
  end

  test "a scope on a non-given item is rejected" do
    a = build_episode_with_survivors(1).last.first
    ai = AppearanceItem.new(appearance: a, item: @pot, source: "brought", given_scope: "team")
    assert_not ai.valid?
    assert_includes ai.errors[:given_scope], "only applies to given items"
  end

  test "an unknown scope is rejected" do
    a = build_episode_with_survivors(1).last.first
    ai = AppearanceItem.new(appearance: a, item: @pot, source: "given", given_scope: "everyone")
    assert_not ai.valid?
    assert ai.errors[:given_scope].any?
  end

  test "the database refuses a scope on a non-given row and an unknown scope" do
    a = build_episode_with_survivors(1).last.first
    brought = AppearanceItem.create!(appearance: a, item: @pot, source: "brought")
    # each bad write runs in a savepoint so the failed statement does not poison the test transaction
    assert_raises(ActiveRecord::StatementInvalid) { AppearanceItem.transaction(requires_new: true) { brought.update_columns(given_scope: "team") } }

    given = AppearanceItem.create!(appearance: a, item: @hide, source: "given")
    assert_raises(ActiveRecord::StatementInvalid) { AppearanceItem.transaction(requires_new: true) { given.update_columns(given_scope: "bogus") } }
  end

  test "changing a given row to brought drops the scope; changing brought to given makes it team" do
    a = build_episode_with_survivors(1).last.first
    ai = AppearanceItem.create!(appearance: a, item: @pot, source: "given", given_scope: "individual")
    ai.update!(source: "brought")
    assert_nil ai.reload.given_scope

    ai.update!(source: "given")
    assert_equal "team", ai.reload.given_scope
  end

  test "re-saving a given row from before the column existed does not decide its scope" do
    a = build_episode_with_survivors(1).last.first
    ai = AppearanceItem.create!(appearance: a, item: @pot, source: "given")
    ai.update_columns(given_scope: nil) # as it is in production until the backfill runs
    ai.reload.update!(quantity: 2)
    assert_nil ai.reload.given_scope
    ai.update!(given_scope: "individual")
    assert_equal "individual", ai.reload.given_scope
  end

  # ----- counting -----

  test "a team item given to three survivors counts once" do
    _, apps = build_episode_with_survivors(3)
    give(@pot, apps, scope: "team")
    assert_equal 3, AppearanceItem.where(item: @pot).count, "three rows are stored (one per survivor page)"
    assert_equal 1, AppearanceItem.where(item: @pot).given_count
    assert_equal 1, AppearanceItem.where(item: @pot).counted.count
  end

  test "an individual item given to three survivors counts three times" do
    _, apps = build_episode_with_survivors(3)
    give(@pot, apps, scope: "individual")
    assert_equal 3, AppearanceItem.where(item: @pot).given_count
  end

  test "unclassified given rows count per row, exactly as before the column existed" do
    _, apps = build_episode_with_survivors(2)
    give(@pot, apps, scope: "team")
    AppearanceItem.where(item: @pot).update_all(given_scope: nil)
    assert_equal 2, AppearanceItem.where(item: @pot).given_count
  end

  test "a team item counts once per episode, so two episodes make two" do
    _, apps1 = build_episode_with_survivors(2)
    _, apps2 = build_episode_with_survivors(2)
    give(@pot, apps1)
    give(@pot, apps2)
    assert_equal 2, AppearanceItem.where(item: @pot).given_count
  end

  test "a team item with quantity 2 counts as two, not four" do
    _, apps = build_episode_with_survivors(2)
    give(@pot, apps, quantity: 2)
    assert_equal 2, AppearanceItem.where(item: @pot).given_count
  end

  test "an individual item with quantity 2 each counts every unit" do
    _, apps = build_episode_with_survivors(2)
    give(@pot, apps, scope: "individual", quantity: 2)
    assert_equal 4, AppearanceItem.where(item: @pot).given_count
  end

  test "brought items are unaffected: every survivor's own item counts" do
    _, apps = build_episode_with_survivors(3)
    apps.each { |a| AppearanceItem.create!(appearance: a, item: @pot, source: "brought") }
    assert_equal 3, AppearanceItem.where(item: @pot).brought.counted.sum(:quantity)
    assert_equal 3, AppearanceItem.where(item: @pot).counted.count
    assert_equal 0, AppearanceItem.where(item: @pot).given_count
  end

  test "a solo episode counts one either way" do
    _, apps_team = build_episode_with_survivors(1)
    _, apps_ind  = build_episode_with_survivors(1)
    give(@pot, apps_team, scope: "team")
    give(@hide, apps_ind, scope: "individual")
    assert_equal 1, AppearanceItem.where(item: @pot).given_count
    assert_equal 1, AppearanceItem.where(item: @hide).given_count
  end

  test "subtype variants are separate items: elk hide and buck hide are two, the same subtype is one" do
    _, apps = build_episode_with_survivors(2)
    give(@hide, apps, subtype: "elk")
    give(@hide, apps, subtype: "buck")
    give(@pot, apps) # and an item with no subtype
    assert_equal 2, AppearanceItem.where(item: @hide).given_count
    assert_equal 1, AppearanceItem.where(item: @pot).given_count
  end

  test "a blank subtype and no subtype are the same team item" do
    _, (a1, a2) = build_episode_with_survivors(2)
    AppearanceItem.create!(appearance: a1, item: @pot, source: "given", subtype: nil)
    AppearanceItem.create!(appearance: a2, item: @pot, source: "given", subtype: "")
    assert_equal 1, AppearanceItem.where(item: @pot).given_count
  end

  test "team and individual rows of the same item in one episode each count by their own rule" do
    _, apps = build_episode_with_survivors(3)
    give(@hide, apps, subtype: "elk", scope: "team")        # one shared
    give(@hide, apps, subtype: "buck", scope: "individual") # one each
    assert_equal 1 + 3, AppearanceItem.where(item: @hide).given_count
  end

  test "counted composes with other filters such as country" do
    peru   = Location.create!(country: "Peru", site: "Counted Site")
    _, p1  = build_episode_with_survivors(2, location: peru)
    _, c1  = build_episode_with_survivors(2) # Costa Rica
    give(@pot, p1)
    give(@pot, c1)
    in_peru = AppearanceItem.where(item: @pot).joins(appearance: { episode: :location }).where(locations: { country: "Peru" })
    assert_equal 1, in_peru.given_count
    assert_equal 2, AppearanceItem.where(item: @pot).given_count
  end

  test "item_totals ranks by deduplicated quantity and leaves brought alone" do
    _, apps = build_episode_with_survivors(3)
    give(@pot, apps, scope: "team")                  # 1
    give(@hide, apps, scope: "individual")           # 3
    apps.each { |a| AppearanceItem.create!(appearance: a, item: @pot, source: "brought") } # 3 brought

    given = AppearanceItem.item_totals("given").where(items: { id: [@pot.id, @hide.id] }).to_a
    assert_equal [[@hide.id, 3], [@pot.id, 1]], given.map { |r| [r.id, r.total.to_i] }

    brought = AppearanceItem.item_totals("brought").where(items: { id: @pot.id }).to_a
    assert_equal [[@pot.id, 3]], brought.map { |r| [r.id, r.total.to_i] }
  end

  # ----- the episode-page banner -----

  test "team_given_banner hoists team rows once and leaves individual rows per survivor" do
    ep, apps = build_episode_with_survivors(2)
    give(@pot, apps, scope: "team")
    give(@hide, apps, scope: "individual")
    banner = AppearanceItem.team_given_banner(Appearance.where(episode: ep).includes(:survivor, :appearance_items))

    assert_equal [@pot.id], banner[:groups].map { |g| g.appearance_item.item_id }
    assert banner[:groups].first.everyone
    assert_equal AppearanceItem.where(item: @pot).pluck(:id).sort, banner[:hoisted_ids].to_a.sort
  end

  test "team_given_banner names the recipients when a team item is on only some survivors" do
    ep, (a1, a2, _a3) = build_episode_with_survivors(3)
    give(@pot, [a1, a2], scope: "team")
    group = AppearanceItem.team_given_banner(Appearance.where(episode: ep).includes(:survivor, :appearance_items))[:groups].first
    assert_not group.everyone
    assert_equal 2, group.recipients.size
  end

  test "team_given_banner keeps the old identical-rows rule for unclassified rows only" do
    ep, apps = build_episode_with_survivors(2)
    give(@pot, apps)
    AppearanceItem.where(item: @pot).update_all(given_scope: nil)
    load_ep = -> { AppearanceItem.team_given_banner(Appearance.where(episode: ep).includes(:survivor, :appearance_items)) }
    assert_equal 1, load_ep.call[:groups].size, "identical unclassified rows read as a team item"

    AppearanceItem.where(item: @pot, appearance_id: apps.first.id).update_all(given_scope: "individual")
    assert_equal 0, load_ep.call[:groups].size, "a deliberate classification is never swallowed by the heuristic"
  end
end
