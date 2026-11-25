require "test_helper"

class SlugUrlHelperTest < ActionView::TestCase
  setup do
    NameSlugs.reset!
    Location.create!(country: "Côte d'Ivoire", site: "Helper", latitude: 1.0, longitude: 1.0)
    FoodSource.create!(episode: episodes(:one), name: "angel fish", category: "animal")
    EpisodeShelter.create!(episode: episodes(:one), shelter_type: "Lean-to")
    Item.create!(name: "flint", item_type: "fire starting tool")
  end

  test "name routes take a name positionally or by keyword and emit the slug" do
    assert_equal "/episodes/by_country/cote-d-ivoire", by_country_episodes_path("Côte d'Ivoire")
    assert_equal "/episodes/by_country/cote-d-ivoire", by_country_episodes_path(country: "Côte d'Ivoire")
    assert_equal "/episodes/by_country/cote-d-ivoire?page=2", by_country_episodes_path("Côte d'Ivoire", page: 2)
    assert_equal "/food_sources/angel-fish", food_source_path("angel fish")
    assert_equal "/food_sources/angel-fish", food_source_path(name: "angel fish")
    assert_equal "/shelters/lean-to", shelter_path(shelter_type: "Lean-to")
    assert_equal "/items/types/fire-starting-tool", type_items_path("fire starting tool")
    assert_equal "https://example.org/episodes/by_country/cote-d-ivoire",
                 by_country_episodes_url("Côte d'Ivoire", host: "example.org", protocol: "https")
  end

  test "a name path is idempotent for an existing slug" do
    assert_equal "/episodes/by_country/cote-d-ivoire", by_country_episodes_path("cote-d-ivoire")
  end

  test "episode and item paths take a record or a bare id and always emit the slug" do
    ep = episodes(:one)
    it = items(:one)
    assert_equal "/episodes/testseriesa-s1e1-test-episode-a", episode_path(ep)
    assert_equal "/episodes/testseriesa-s1e1-test-episode-a", episode_path(ep.id)
    assert_equal "/episodes/testseriesa-s1e1-test-episode-a", episode_path(ep.id.to_s)
    assert_equal "/episodes/testseriesa-s1e1-test-episode-a", episode_path(id: ep.id)
    assert_equal "/items/sampleitema#item-shop", item_path(it.id, anchor: "item-shop")
    assert_equal "/items/sampleitema?country=Peru", item_path(it, country: "Peru")
  end

  test "an id with no slug yet stays an id" do
    ep = episodes(:one)
    ep.update_columns(slug: nil)
    assert_equal "/episodes/#{ep.id}", episode_path(ep.id)
    assert_equal "/episodes/#{ep.id}", episode_path(ep.reload)
  end

  test "slug_internal_links rewrites old links inside stored HTML and leaves the rest" do
    ep = episodes(:one)
    html = %(<a href="/episodes/#{ep.id}">x</a> <a href="/episodes/#{ep.id}?a=1">y</a> <a href="/episodes/by_country/C%C3%B4te%20d'Ivoire">c</a> ) +
           %(<a href="/episodes/by_country/Atlantis">z</a> <a href="/survivors/1">s</a> <a href="https://x.com/episodes/#{ep.id}">ext</a>)
    out = slug_internal_links(html)
    assert_includes out, %(href="/episodes/testseriesa-s1e1-test-episode-a">x)
    assert_includes out, %(href="/episodes/testseriesa-s1e1-test-episode-a?a=1">y)
    assert_includes out, %(href="/episodes/by_country/cote-d-ivoire">c)
    assert_includes out, %(href="/episodes/by_country/Atlantis">z)   # unknown: left as written
    assert_includes out, %(href="/survivors/1">s)
    assert_includes out, %(href="https://x.com/episodes/#{ep.id}">ext)
  end

  test "slug_site_url rewrites our own id URLs only" do
    ep = episodes(:one)
    assert_equal "https://www.nakedandafraidfan.com/episodes/testseriesa-s1e1-test-episode-a",
                 slug_site_url("https://www.nakedandafraidfan.com/episodes/#{ep.id}")
    assert_equal "https://www.nakedandafraidfan.com/items/sampleitema",
                 slug_site_url("https://www.nakedandafraidfan.com/items/#{items(:one).id}")
    assert_equal "https://example.com/episodes/#{ep.id}", slug_site_url("https://example.com/episodes/#{ep.id}")
  end
end
