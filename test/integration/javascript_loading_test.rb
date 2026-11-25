require "test_helper"

# Only the code every page needs is in the global bundle (app/javascript/app.js)
# and modulepreloaded; page-specific modules are imported by the pages that use
# them.
class JavascriptLoadingTest < ActionDispatch::IntegrationTest
  PAGE_ONLY = %w[leaflet locations_map episode_form forum_mentions admin_views_chart gtag].freeze

  setup { ENV["FORUM_ENABLED"] = "true" }
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user) = post(session_path, params: { email_address: user.email_address, password: "password" })

  def preloaded(doc) = doc.css("link[rel=modulepreload]").map { |l| l["href"].to_s }

  def module_imports(doc)
    doc.css("script[type=module]").flat_map { |s| s.text.scan(/import "([^"]+)"/).flatten }
  end

  test "the homepage does not preload page-specific or unused modules" do
    get "/"
    doc = Nokogiri::HTML(response.body)
    urls = preloaded(doc)

    assert urls.any? { |u| u.include?("/assets/app-") }, "the entry module should still be preloaded"
    assert urls.any? { |u| u.include?("turbo.min-") }
    PAGE_ONLY.each { |m| assert urls.none? { |u| u.include?("/assets/#{m}-") }, "#{m} should not be preloaded on the homepage" }
    assert urls.none? { |u| u.include?("/assets/json_ld/") }, "unused json_ld modules should not be preloaded"
  end

  test "the homepage imports only the application entry module" do
    get "/"
    assert_equal [ "application" ], module_imports(Nokogiri::HTML(response.body))
  end

  test "the import map still resolves every pinned module, preloaded or not" do
    get "/"
    map = JSON.parse(Nokogiri::HTML(response.body).at_css("script[type=importmap]").text)["imports"]
    PAGE_ONLY.each { |m| assert map.key?(m), "#{m} must stay pinned so pages can import it" }
  end

  test "app.js imports no page-specific module and only pinned modules" do
    src = Rails.root.join("app/javascript/app.js").read
    imported = src.scan(/^import "([^"]+)"/).flatten
    PAGE_ONLY.each { |m| assert_not_includes imported, m }
    get "/"
    pins = JSON.parse(Nokogiri::HTML(response.body).at_css("script[type=importmap]").text)["imports"].keys
    imported.each { |m| assert_includes pins, m, "#{m} is imported by app.js but not pinned" }
  end

  test "gtag.js is loaded once, as a classic script, not also as a module" do
    get "/"
    doc = Nokogiri::HTML(response.body)
    assert_equal 1, doc.css("script[src*='/assets/gtag-']").size
    assert_not_includes module_imports(doc), "gtag"
  end

  test "the locations page imports the map module" do
    get "/locations"
    assert_includes module_imports(Nokogiri::HTML(response.body)), "locations_map"
  end

  test "an episodes-by-country page imports the map module" do
    location = locations(:one)
    location.update!(latitude: 10.5, longitude: -85.4) # the map only renders for geocoded countries
    get by_country_episodes_path(country: NameSlugs.slug(:country, location.country))
    assert_includes module_imports(Nokogiri::HTML(response.body)), "locations_map"
  end

  test "a page without a map does not import the map module" do
    [ "/survivors", "/episodes", "/items", "/about" ].each do |path|
      get path
      assert_not_includes module_imports(Nokogiri::HTML(response.body)), "locations_map", path
    end
  end

  test "the admin episode form imports episode_form; public pages do not" do
    sign_in_as(users(:admin))
    get edit_admin_episode_path(episodes(:one))
    assert_response :success
    assert_includes module_imports(Nokogiri::HTML(response.body)), "episode_form"

    get new_admin_episode_path
    assert_response :success
    assert_includes module_imports(Nokogiri::HTML(response.body)), "episode_form"

    get episode_path(episodes(:one))
    assert_not_includes module_imports(Nokogiri::HTML(response.body)), "episode_form"
  end

  test "the admin dashboard still imports its chart module" do
    sign_in_as(users(:admin))
    get admin_root_path
    assert_response :success
    assert_includes module_imports(Nokogiri::HTML(response.body)), "admin_views_chart"
  end

  test "forum composers import forum_mentions" do
    owner = users(:one)
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: owner, title: "Mentions")
    post  = topic.posts.create!(user: owner, body: "Hello")
    sign_in_as(owner)

    get new_forum_topic_path
    assert_response :success
    assert_includes module_imports(Nokogiri::HTML(response.body)), "forum_mentions"

    get forum_topic_path(topic)
    assert_response :success
    assert_includes module_imports(Nokogiri::HTML(response.body)), "forum_mentions"

    get edit_forum_post_path(post)
    assert_response :success
    assert_includes module_imports(Nokogiri::HTML(response.body)), "forum_mentions"
  end

  test "every textarea marked for mentions has the module on its page" do
    owner = users(:one)
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: owner, title: "Mentions 2")
    topic.posts.create!(user: owner, body: "Hello")
    sign_in_as(owner)

    [ new_forum_topic_path, forum_topic_path(topic) ].each do |path|
      get path
      doc = Nokogiri::HTML(response.body)
      next if doc.css("textarea[data-mentions]").empty?
      assert_includes module_imports(doc), "forum_mentions", path
    end
  end
end
