require "test_helper"
require "minitest/mock"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  HOST = "https://www.nakedandafraidfan.com".freeze

  setup do
    # The test env uses :null_store; use a real store here to exercise the caching.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @original_cache }

  def locs
    Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
  end

  test "serves XML from the database, not a static file" do
    refute File.exist?(Rails.root.join("public/sitemap.xml")), "a static public/sitemap.xml would shadow the dynamic route"
    refute File.exist?(Rails.root.join("public/sitemap1.xml"))

    get "/sitemap.xml"
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_equal "urlset", Nokogiri::XML(response.body).root.name
  end

  test "includes the shop, shop guides, a survivor and an episode" do
    get "/sitemap.xml"
    assert_includes locs, "#{HOST}/shop"
    assert_includes locs, "#{HOST}/shop/guides"
    ShopCatalog.guides.each { |g| assert_includes locs, "#{HOST}/shop/guides/#{g.slug}" }
    assert_includes locs, "#{HOST}#{survivor_path(survivors(:one))}"
    assert_includes locs, "#{HOST}#{episode_path(episodes(:one))}"
    assert_includes locs, "#{HOST}#{season_path(seasons(:one))}"
    assert_includes locs, "#{HOST}#{item_path(items(:one))}"
  end

  test "excludes affiliate redirects, admin, forum and auth pages" do
    get "/sitemap.xml"
    assert locs.none? { |l| l.include?("/go/") }, "affiliate redirects must not be listed"
    assert locs.none? { |l| l.include?("/admin") }
    assert locs.none? { |l| l.include?("/forum") }
    assert locs.none? { |l| l =~ %r{/(session|passwords|signup|contact|page_view_ping)} }
  end

  test "URLs are absolute, on the canonical host and unique" do
    host! "evil.example.com"
    get "/sitemap.xml"
    assert locs.all? { |l| l.start_with?("#{HOST}/") }, "every loc should use #{HOST}"
    refute_includes response.body, "evil.example.com"
    assert_equal locs.uniq, locs
    assert_includes locs, "#{HOST}/"
  end

  test "carries lastmod, changefreq and priority" do
    get "/sitemap.xml"
    url = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url").find { |u| u.at("loc").text == "#{HOST}#{survivor_path(survivors(:one))}" }
    assert_equal "weekly", url.at("changefreq").text
    assert_equal "0.7", url.at("priority").text
    assert_equal survivors(:one).updated_at.utc.iso8601, url.at("lastmod").text
  end

  test "is cacheable with an ETag and answers conditional requests with 304" do
    get "/sitemap.xml"
    assert_match(/public/, response.headers["Cache-Control"])
    assert_match(/max-age=3600/, response.headers["Cache-Control"])
    etag = response.headers["ETag"]
    assert etag.present?

    get "/sitemap.xml", headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "a new record appears after the cache is invalidated by the data change" do
    get "/sitemap.xml"
    sitemap_before = response.body

    survivor = Survivor.create!(full_name: "Sitemap Newcomer")
    get "/sitemap.xml"
    assert_includes locs, "#{HOST}#{survivor_path(survivor)}"
    refute_equal sitemap_before, response.body
  end

  test "is served from the cache between data changes" do
    get "/sitemap.xml"
    key = SitemapUrls.cache_key
    assert Rails.cache.exist?(key)

    SitemapUrls.stub(:to_xml, -> { raise "should not rebuild" }) do
      get "/sitemap.xml"
      assert_response :success
    end
  end

  test "the old sitemap1.xml permanently redirects to /sitemap.xml" do
    get "/sitemap1.xml"
    assert_response :moved_permanently
    assert_redirected_to "/sitemap.xml"
  end

  test "robots.txt points at the canonical sitemap" do
    assert_includes File.read(Rails.root.join("public/robots.txt")), "Sitemap: #{HOST}/sitemap.xml"
  end
end
