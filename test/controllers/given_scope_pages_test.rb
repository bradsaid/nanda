require "test_helper"
require "minitest/mock"

# One team item stored on every survivor's row must read as ONE item on every page that
# counts or ranks given items, while each survivor's own page still shows it.
class GivenScopePagesTest < ActionDispatch::IntegrationTest
  setup do
    @team_pot  = Item.create!(name: "zzteampot")
    @each_axe  = Item.create!(name: "zzeachaxe")
    @ep, @apps = build_episode_with_survivors(3, title: "Scope Pages Ep")
    give(@team_pot, @apps, scope: "team")
    give(@each_axe, @apps, scope: "individual")
  end

  def top_given_total(name, selector: "#top-given")
    row = css_select("#{selector} tbody tr").find { |tr| tr.text.include?(name) }
    row && row.css("td").last.text.strip.to_i
  end

  # ----- items index -----

  test "items index Top Given counts a team item once and an individual item per survivor" do
    get items_path
    assert_response :success
    assert_equal 1, top_given_total("zzteampot")
    assert_equal 3, top_given_total("zzeachaxe")
  end

  test "items index Top Given follows the country filter and still dedupes" do
    get items_path(country: @ep.location.country)
    assert_equal 1, top_given_total("zzteampot")
    assert_equal 3, top_given_total("zzeachaxe")
  end

  test "Top Brought is unaffected: three survivors bringing the same item is three" do
    brought = Item.create!(name: "zzbroughtknife")
    @apps.each { |a| AppearanceItem.create!(appearance: a, item: brought, source: "brought") }
    get items_path
    assert_equal 3, top_given_total("zzbroughtknife", selector: "#top-brought")
  end

  # ----- home -----

  test "the home page's Top Items Given counts the team item once" do
    get root_path
    assert_response :success
    rows = css_select("h2").find { |h| h.text.include?("Top Items — Given") }.parent.css("tbody tr")
    team = rows.find { |tr| tr.text.include?("zzteampot") }
    axe  = rows.find { |tr| tr.text.include?("zzeachaxe") }
    assert_equal 1, team.css("td").last.text.strip.to_i
    assert_equal 3, axe.css("td").last.text.strip.to_i
  end

  # ----- item page -----

  test "item page lists the team-given episode once, tagged as shared with the team" do
    get item_path(@team_pot)
    assert_response :success
    rows = css_select("table tbody tr").select { |tr| tr.text.include?("Scope Pages Ep") }
    assert_equal 1, rows.size, "one row per episode, not per survivor"
    assert_match(/shared with team/, rows.first.text)
    @apps.each { |a| assert_match a.survivor.full_name, rows.first.text }
  end

  test "item page tags an individually given item differently" do
    get item_path(@each_axe)
    row = css_select("table tbody tr").find { |tr| tr.text.include?("Scope Pages Ep") }
    assert_match(/one each/, row.text)
    assert_no_match(/shared with team/, row.text)
  end

  test "item page by-country total counts the team item once and the individual item per survivor" do
    get item_path(@team_pot)
    cell = css_select("td[data-label=Total]").find { |td| td.parent.text.include?(@ep.location.country) }
    assert_equal 1, cell.text.strip.to_i

    get item_path(@each_axe)
    cell = css_select("td[data-label=Total]").find { |td| td.parent.text.include?(@ep.location.country) }
    assert_equal 3, cell.text.strip.to_i
  end

  test "item type page tags the recipients cell" do
    get type_items_path(@team_pot.item_type)
    assert_response :success
    row = css_select("table tbody tr").find { |tr| tr.text.include?("Scope Pages Ep") }
    assert_match(/shared with team/, row.text)
  end

  # ----- survivor page -----

  test "each survivor's own page still shows the team item, marked as shared with the team" do
    @apps.each do |a|
      get survivor_path(a.survivor)
      assert_response :success
      assert_select "span.badge", text: /zzteampot.*\(shared with team\)/m
      assert_select "span.badge", text: /zzeachaxe/
      badge = css_select("span.badge").find { |b| b.text.include?("zzeachaxe") }
      assert_match(/zzteampot \(shared with team\)/, badge.text)
      assert_no_match(/zzeachaxe \(shared with team\)/, badge.text, "an individually given item carries no team marker")
      assert_select "ul.list-group li", text: /zzteampot/ # Items Given list: they had it
    end
  end

  # ----- episode page -----

  test "episode page shows a team item once in a Team given banner and not again per survivor" do
    get episode_path(@ep)
    assert_response :success
    assert_select ".bg-light.border-bottom", text: /Team given:.*zzteampot/m
    assert_equal 1, response.body.scan("zzteampot").size, "the team item is named once on the page"
    # the individually given item stays on every survivor's row
    assert_equal 3, css_select("td[data-label=Items]").count { |td| td.text.include?("zzeachaxe") }
  end

  test "episode page names the recipients when a team item went to only part of the cast" do
    part = Item.create!(name: "zzpartpot")
    give(part, @apps.first(2), scope: "team")
    get episode_path(@ep)
    assert_select ".bg-light.border-bottom", text: /zzpartpot\s*\(.+ and .+\)/m
  end

  test "episode page keeps the old banner for unclassified identical rows" do
    legacy = Item.create!(name: "zzlegacypot")
    old_ep, old_apps = build_episode_with_survivors(2, title: "Legacy Scope Ep")
    give(legacy, old_apps).each { |ai| ai.update_columns(given_scope: nil) }
    get episode_path(old_ep)
    assert_select ".bg-light.border-bottom", text: /zzlegacypot/
    assert_equal 1, response.body.scan("zzlegacypot").size
  end
end

# The shop shelf lists the busiest gear first; a team item must not look busier than it is.
class GivenScopeGearShelfTest < ActiveSupport::TestCase
  class Shelf
    include GearShelf
    attr_reader :shop_shelf
    public :build_gear_shelf
  end

  def product(item)
    { item: item, category: "other", product: "#{item} product", match: "likely", evidence_url: "https://e.com/#{item.parameterize}",
      buy: [{ store: "x.com", url: "https://x.com/#{item.parameterize}" }] }.with_indifferent_access
  end

  def shelf_order(&scope)
    ShopCatalog.stub(:products, [product("zzgearpot"), product("zzgearknife")]) do
      s = Shelf.new
      s.build_gear_shelf(label: "x", max_groups: 8, limit: 3, &scope)
      s.shop_shelf.groups.map { |g| g.item.name }
    end
  end

  test "an item given to the whole team ranks as one holder, not one per survivor" do
    pot   = Item.create!(name: "zzgearpot")
    knife = Item.create!(name: "zzgearknife")
    ep, apps = build_episode_with_survivors(3)
    give(pot, apps, scope: "team")                                              # 1 pot, 3 rows
    apps.first(2).each { |a| AppearanceItem.create!(appearance: a, item: knife, source: "brought") } # 2 knives

    order = shelf_order { |scope| scope.where(episodes: { id: ep.id }) }
    assert_equal %w[zzgearknife zzgearpot], order, "2 brought knives outrank 1 team-given pot"
  end

  test "an item given to each person still ranks by survivor" do
    pot   = Item.create!(name: "zzgearpot")
    knife = Item.create!(name: "zzgearknife")
    ep, apps = build_episode_with_survivors(3)
    give(pot, apps, scope: "individual")
    apps.first(2).each { |a| AppearanceItem.create!(appearance: a, item: knife, source: "brought") }

    order = shelf_order { |scope| scope.where(episodes: { id: ep.id }) }
    assert_equal %w[zzgearpot zzgearknife], order
  end
end
