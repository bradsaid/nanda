require "test_helper"

# The admin episode form: choosing Team vs Each person for a given item, and keeping it.
class Admin::EpisodeGivenScopeTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    @pot    = Item.create!(name: "admin scope pot")
    @hide   = Item.create!(name: "admin scope hide")
    @ep, @apps = build_episode_with_survivors(2, title: "Admin Scope Ep")
  end

  def item_row(item, source: "given", scope: nil, subtype: nil, id: nil, destroy: nil)
    { id: id, item_id: item.id, source: source, given_scope: scope, subtype: subtype, quantity: 1, _destroy: destroy }.compact
  end

  def patch_items(rows_by_appearance)
    attrs = rows_by_appearance.each_with_index.to_h do |(app, rows), i|
      [i.to_s, { id: app.id, survivor_id: app.survivor_id, appearance_items_attributes: rows.each_with_index.to_h { |r, j| [j.to_s, r] } }]
    end
    patch admin_episode_path(@ep), params: { episode: { appearances_attributes: attrs } }
  end

  # ----- saving the choice -----

  test "a given item saved with Team is stored as team on each survivor's row" do
    patch_items(@apps.to_h { |a| [a, [item_row(@pot, scope: "team")]] })
    assert_redirected_to admin_episodes_path
    assert_equal %w[team team], AppearanceItem.where(item: @pot).pluck(:given_scope)
    assert_equal 1, AppearanceItem.where(item: @pot).given_count
  end

  test "Each person is stored as individual and counts per survivor" do
    patch_items(@apps.to_h { |a| [a, [item_row(@pot, scope: "individual")]] })
    assert_equal %w[individual individual], AppearanceItem.where(item: @pot).pluck(:given_scope)
    assert_equal 2, AppearanceItem.where(item: @pot).given_count
  end

  test "a given item submitted without a scope defaults to team" do
    patch_items(@apps.to_h { |a| [a, [item_row(@pot)]] })
    assert_equal %w[team team], AppearanceItem.where(item: @pot).pluck(:given_scope)
  end

  test "creating an episode with a given item keeps the scope too" do
    assert_difference "AppearanceItem.count", 1 do
      post admin_episodes_path, params: { episode: {
        season_id: seasons(:one).id, number_in_season: 77, title: "Create Scope", location_id: locations(:one).id,
        appearances_attributes: { "0" => { survivor_id: survivors(:one).id, role: "solo",
          appearance_items_attributes: { "0" => item_row(@pot, scope: "individual") } } }
      } }
    end
    assert_equal ["individual"], AppearanceItem.where(item: @pot).pluck(:given_scope)
  end

  test "a brought item carries no scope even if one is submitted blank" do
    patch_items({ @apps.first => [item_row(@pot, source: "brought", scope: "")] })
    ai = AppearanceItem.find_by!(item: @pot)
    assert_equal "brought", ai.source
    assert_nil ai.given_scope
  end

  # ----- editing does not reset it -----

  test "editing the episode without touching the item keeps an individual scope" do
    rows = give(@pot, @apps, scope: "individual")
    patch admin_episode_path(@ep), params: { episode: { title: "Renamed", appearances_attributes: {
      "0" => { id: @apps[0].id, survivor_id: @apps[0].survivor_id, role: "duo", appearance_items_attributes: { "0" => { id: rows[0].id, item_id: @pot.id, source: "given", quantity: 1 } } }
    } } }
    assert_redirected_to admin_episodes_path
    assert_equal %w[individual individual], AppearanceItem.where(item: @pot).pluck(:given_scope)
  end

  test "the edit form round-trips: re-submitting what it rendered keeps every scope" do
    give(@pot, @apps, scope: "individual")
    give(@hide, @apps, scope: "team")
    get edit_admin_episode_path(@ep)
    assert_response :success
    selected = css_select("select.item-given-scope:not([disabled])").map { |s| s.css("option[selected]").first&.[]("value") }
    assert_equal %w[individual individual team team].sort, selected.sort
  end

  test "changing Team to Each person saves and is recorded in the changelog" do
    rows = give(@pot, @apps, scope: "team")
    patch_items({ @apps[0] => [item_row(@pot, scope: "individual", id: rows[0].id)] })
    assert_equal "individual", rows[0].reload.given_scope
    change = rows[0].versions.last.object_changes
    assert_match(/given_scope/, change)
    assert_match(/individual/, change)
  end

  test "switching a given row to brought drops the scope instead of erroring" do
    rows = give(@pot, @apps, scope: "team")
    patch_items({ @apps[0] => [item_row(@pot, source: "brought", id: rows[0].id)] })
    assert_redirected_to admin_episodes_path
    assert_nil rows[0].reload.given_scope
  end

  test "a legacy given row with no scope stays unclassified until someone picks one" do
    rows = give(@pot, @apps, scope: "team")
    rows.each { |r| r.update_columns(given_scope: nil) }
    patch_items({ @apps[0] => [item_row(@pot, id: rows[0].id, scope: "")] })
    assert_nil rows[0].reload.given_scope

    get edit_admin_episode_path(@ep)
    assert_select "select.item-given-scope option", text: /Not set yet/, minimum: 1
  end

  # ----- the form itself -----

  test "new-item template and Quick Add default to Team, with Each person as the alternative" do
    get edit_admin_episode_path(@ep)
    assert_response :success
    assert_select "template#item-template select.item-given-scope option[selected][value=team]"
    assert_select "template#item-template select.item-given-scope option[value=individual]", text: "Each person"
    assert_select "input#bulk-given-scope-team[checked]"
    assert_select "input#bulk-given-scope-individual"
    assert_select "#bulk-given-card", text: /Team \(one shared item\)/
  end

  test "the scope select is hidden and disabled for non-given rows" do
    AppearanceItem.create!(appearance: @apps[0], item: @pot, source: "brought")
    get edit_admin_episode_path(@ep)
    select = css_select(".item-entry select.item-given-scope").first
    assert select["disabled"], "not submitted for a brought item"
    assert_match(/display:\s*none/, select["style"])
  end
end
