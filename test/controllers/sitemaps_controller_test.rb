require "test_helper"
require "minitest/mock"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  HOST = "https://www.nakedandafraidfan.com".freeze

  setup do
    # The test env uses :null_store; use a real store here to exercise the caching.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
    ENV["FORUM_ENABLED"] = nil
  end

  def url_nodes = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url")

  def lastmod_of(path)
    url_nodes.find { |u| u.at("loc").text == "#{HOST}#{path}" }&.at("lastmod")&.text
  end

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

  test "lists the public Community Guidelines page, with the forum off or on" do
    get "/sitemap.xml"
    assert_includes locs, "#{HOST}/forum/guidelines"
    assert_equal 1, locs.count("#{HOST}/forum/guidelines")
    assert locs.none? { |l| l.end_with?("/guidelines") && !l.end_with?("/forum/guidelines") }, "/guidelines only redirects"
  end

  test "excludes affiliate redirects, admin and auth pages" do
    get "/sitemap.xml"
    assert locs.none? { |l| l.include?("/go/") }, "affiliate redirects must not be listed"
    assert locs.none? { |l| l.include?("/admin") }
    assert locs.none? { |l| l =~ %r{/(session|passwords|signup|page_view_ping)} }
  end

  test "lists the contact, privacy policy and terms pages" do
    get "/sitemap.xml"
    %w[/contact /privacy_policy /terms_of_service].each { |path| assert_includes locs, "#{HOST}#{path}" }
  end

  test "does not list /home (it redirects to /) or any paginated or parameterised URL" do
    get "/sitemap.xml"
    assert_not_includes locs, "#{HOST}/home"
    assert locs.none? { |l| l.include?("?") }, "only clean first-page URLs belong in the sitemap"
  end

  test "with the forum off, only the Community Guidelines page is listed under /forum" do
    ENV["FORUM_ENABLED"] = nil
    Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Hidden while closed")
    get "/sitemap.xml"
    assert_equal ["#{HOST}/forum/guidelines"], locs.select { |l| l.include?("/forum") }
  end

  test "with the forum open, lists the topic list and live topics but not deleted ones" do
    ENV["FORUM_ENABLED"] = "true"
    live    = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Live topic")
    deleted = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Deleted topic")
    deleted.update!(deleted_at: Time.current)
    live.update_columns(last_post_at: Time.utc(2026, 5, 6, 7, 8, 9))

    get "/sitemap.xml"
    assert_includes locs, "#{HOST}/forum"
    assert_includes locs, "#{HOST}#{forum_topic_path(live)}"
    assert_not_includes locs, "#{HOST}#{forum_topic_path(deleted)}"
    assert_equal "2026-05-06T07:08:09Z", lastmod_of(forum_topic_path(live))
    assert locs.none? { |l| l =~ %r{/forum/(users|mentions|categories|topics/new)} }
  end

  test "toggling the forum, or adding/removing a topic, changes the cache key" do
    ENV["FORUM_ENABLED"] = nil
    closed = SitemapUrls.cache_key
    ENV["FORUM_ENABLED"] = "true"
    open_key = SitemapUrls.cache_key
    assert_not_equal closed, open_key

    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Key topic")
    with_topic = SitemapUrls.cache_key
    assert_not_equal open_key, with_topic
    topic.update!(deleted_at: Time.current)
    assert_not_equal with_topic, SitemapUrls.cache_key
  end

  test "a change to the hand-kept lastmod table changes the cache key (a deploy refreshes the sitemap)" do
    before = SitemapUrls.cache_key
    original = SitemapUrls::STATIC_LASTMOD
    begin
      SitemapUrls.send(:remove_const, :STATIC_LASTMOD)
      SitemapUrls.const_set(:STATIC_LASTMOD, original.merge("/about" => Date.new(2030, 1, 1)).freeze)
      assert_not_equal before, SitemapUrls.cache_key
    ensure
      SitemapUrls.send(:remove_const, :STATIC_LASTMOD)
      SitemapUrls.const_set(:STATIC_LASTMOD, original)
    end
  end

  test "every URL carries a lastmod in W3C datetime format" do
    ENV["FORUM_ENABLED"] = "true"
    Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Dated topic")
    get "/sitemap.xml"
    missing = url_nodes.reject { |u| u.at("lastmod") }.map { |u| u.at("loc").text }
    assert_empty missing, "URLs without <lastmod>"
    url_nodes.each do |u|
      assert_match(/\A\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}Z)?\z/, u.at("lastmod").text, u.at("loc").text)
    end
  end

  test "static pages use the documented revision dates" do
    get "/sitemap.xml"
    assert_equal "2026-11-20", lastmod_of("/privacy_policy")
    assert_equal "2026-11-01", lastmod_of("/terms_of_service")
    assert_equal StaticPagesController::GUIDELINES_UPDATED_ON.iso8601, lastmod_of("/forum/guidelines")
    assert_equal "2026-11-02", lastmod_of("/about")
    assert_equal "2026-10-29", lastmod_of("/podcasts")
  end

  test "list pages take their lastmod from the newest row behind them" do
    stamp = Time.utc(2031, 2, 3, 4, 5, 6)
    survivors(:one).update_columns(updated_at: stamp)
    get "/sitemap.xml"
    assert_equal "2031-02-03T04:05:06Z", lastmod_of("/survivors")
    assert_equal "2031-02-03T04:05:06Z", lastmod_of("/"), "the homepage follows the newest of episodes/survivors/items"
    assert_equal File.mtime(ShopCatalog::PATH).utc.iso8601, lastmod_of("/shop")
    assert_equal File.mtime(ShopCatalog::PATH).utc.iso8601, lastmod_of("/shop/guides")
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
