require "test_helper"
require "minitest/mock"

# Episode pages without a synopsis: a "coming soon" note, `noindex, follow` (meta + header) while
# ThinContent is on, no blank table cells or empty tables, and the repeated gear block collapsed
# at the bottom. The admin synopsis queue lists exactly the episodes that are noindexed.
class ThinEpisodePagesTest < ActionDispatch::IntegrationTest
  def robots_meta = css_select('head meta[name="robots"]').first&.[]("content")

  setup do
    @series = Series.create!(name: "Naked and Afraid")
    @season = Season.create!(series: @series, number: 3, year: 2014)
    @loc    = Location.create!(country: "Colombia", region: "Choco", site: "Camp", latitude: 5.5, longitude: -76.7)
  end

  def episode(number, **attrs)
    Episode.create!({ season: @season, number_in_season: number, title: "Ep #{number}", location: @loc }.merge(attrs))
  end

  def with_env(vars)
    old = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  # ---------- indexability ----------

  test "an episode without a synopsis is noindex, follow in the meta tag and the X-Robots-Tag header, with a coming-soon note" do
    ep = episode(1)
    get episode_path(ep)
    assert_response :success
    assert_equal "noindex, follow", robots_meta
    assert_equal "noindex, follow", response.headers["X-Robots-Tag"]
    assert_select ".episode-synopsis-pending", /Synopsis coming soon/
  end

  test "a whitespace-only or markup-only synopsis counts as missing" do
    [ "   ", "<p>&nbsp;</p>" ].each_with_index do |syn, i|
      get episode_path(episode(10 + i, synopsis: syn))
      assert_equal "noindex, follow", robots_meta, syn.inspect
    end
  end

  test "an episode with a synopsis renders it and stays indexable" do
    ep = episode(2, synopsis: "In the wilds of Colombia, two survivalists look for water.")
    get episode_path(ep)
    assert_nil robots_meta
    assert_nil response.headers["X-Robots-Tag"]
    assert_select ".episode-synopsis-pending", 0
    assert_select ".card-body p", text: "In the wilds of Colombia, two survivalists look for water."
  end

  test "turning NOINDEX_THIN_EPISODES off indexes episodes without a synopsis again" do
    ep = episode(3)
    with_env("NOINDEX_THIN_EPISODES" => "false") do
      get episode_path(ep)
      assert_nil robots_meta
      assert_nil response.headers["X-Robots-Tag"]
      assert_select ".episode-synopsis-pending", /Synopsis coming soon/ # the note stays either way
    end
  end

  test "the admin synopsis queue lists exactly the episodes that are noindexed" do
    with_syn  = episode(4, synopsis: "Something happens.")
    blank     = episode(5, synopsis: "  ")
    nothing   = episode(6)
    markup    = episode(7, synopsis: "<p></p>")

    noindexed = Episode.all.select do |e|
      get episode_path(e)
      robots_meta == "noindex, follow"
    end.map(&:id).sort
    assert_includes noindexed, nothing.id
    assert_not_includes noindexed, with_syn.id

    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    Rails.cache.clear
    get admin_synopsis_queue_path(only: "missing")
    assert_response :success
    listed = css_select("tbody tr").filter_map { |tr| tr.at_css("a[href*='/admin/episodes/']")&.[]("href")&.[](%r{/admin/episodes/([^/]+)/edit}, 1) }
    assert_equal noindexed.size, listed.size
    assert_equal noindexed, listed.map { |key| Episode.friendly.find(key).id }.sort
    assert_includes noindexed, blank.id
    assert_includes noindexed, markup.id
    assert_select "p", /episode pages without a synopsis are served noindex/
  end

  # ---------- cleaner tables ----------

  test "participants: empty columns are left out and no cell shows a dash placeholder" do
    ep = episode(8, synopsis: "x")
    Appearance.create!(episode: ep, survivor: Survivor.create!(full_name: "Ann Alpha"))
    Appearance.create!(episode: ep, survivor: Survivor.create!(full_name: "Bo Beta"), days_lasted: 21, result: "success")
    get episode_path(ep)
    headers = css_select("table th").map { |th| th.text.strip }
    assert_equal [ "Name", "Days", "Result" ], headers
    assert_select "table td", text: "—", count: 0
    # the row with no days or result keeps its row, with empty cells
    ann = css_select("table tbody tr").find { |tr| tr.text.include?("Ann Alpha") }
    assert_equal [ "", "" ], ann.css("td")[1..].map { |td| td.text.strip }
  end

  test "a table with no rows is not rendered, and neither are empty info cards" do
    ep = episode(9, synopsis: "x", location: Location.create!(country: "", region: "", site: ""))
    get episode_path(ep)
    assert_response :success
    assert_select "table", 0
    assert_select ".card-header", text: /Participants/, count: 0
    assert_select "div", text: /Scheduled Days/, count: 0
    assert_select "h2", text: /Traps|Food Sources|Medical Calls|Bushcraft Items/, count: 0
  end

  test "optional columns of the traps, food, medical and bushcraft tables appear only when filled" do
    ep = episode(14, synopsis: "x")
    EpisodeTrap.create!(episode: ep, trap_type: "Snare")
    FoodSource.create!(episode: ep, name: "frog", category: "animal")
    MedicalCall.create!(episode: ep, reason: "Cut")
    BushcraftItem.create!(episode: ep, item_type: "Spear")
    get episode_path(ep)
    assert_response :success
    tables = css_select("table").map { |t| t.css("th").map { |th| th.text.strip } }
    assert_includes tables, [ "Type" ]                                  # traps: only the type is known
    assert_includes tables, [ "Name", "Category", "Obtained By" ]       # food: no method, no tools
    assert_includes tables, [ "Survivor", "Reason", "Tap Out" ]         # medical: no notes
    assert_includes tables, [ "Item" ]                                  # bushcraft: nothing else known
    assert_select "table td", text: "—", count: 0
  end

  # ---------- gear block ----------

  GEAR = [ { item: "pot", category: "pot", product: "Test Pot", match: "similar", evidence_url: "https://e.com/p",
             buy: [ { store: "x.com", url: "https://x.com/p" } ] }.with_indifferent_access ].freeze

  test "the gear block is a collapsed details below the episode content, with sponsored tracked links" do
    ep = episode(15, synopsis: "x")
    survivor = Survivor.create!(full_name: "Pat Pot")
    ap = Appearance.create!(episode: ep, survivor: survivor)
    AppearanceItem.create!(appearance: ap, item: Item.create!(name: "pot"), source: "brought")
    ShopCatalog.stub(:products, GEAR) do
      get episode_path(ep)
    end
    assert_select "details.episode-gear:not([open])" do
      assert_select "summary", /Gear used in this episode \(1 product, affiliate links\)/
      assert_select "section#episode-shop h2", "Shop the Gear From This Episode"
      assert_select "a[href^='/go/'][rel~=sponsored][rel~=nofollow]"
    end
    body = response.body
    assert_operator body.index("episode-gear"), :>, body.index("Participants"), "gear comes after the participants table"
    assert_operator body.index("episode-gear"), :>, body.index("Frequently Asked Questions").to_i
    assert_select ".site-header a.btn-warning[href=?]", "#episode-shop"
  end

  test "an episode with no gear has no gear block" do
    get episode_path(episode(16, synopsis: "x"))
    assert_select "details.episode-gear", 0
  end
end
