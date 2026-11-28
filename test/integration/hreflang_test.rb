require "test_helper"

# hreflang: the English series index (/series) and the es / pt / fr episode guides form one
# alternate set. Each of the four pages emits the identical, complete set (en, es, pt, fr and
# x-default), including a reference to itself, as absolute URLs on the canonical host. No other
# page emits hreflang.
class HreflangTest < ActionDispatch::IntegrationTest
  ORIGIN = "https://www.nakedandafraidfan.com".freeze
  EXPECTED = {
    "en"        => "#{ORIGIN}/series",
    "es"        => "#{ORIGIN}/es/naked-and-afraid-guia-de-episodios",
    "pt"        => "#{ORIGIN}/pt/naked-and-afraid-guia-de-episodios",
    "fr"        => "#{ORIGIN}/fr/naked-and-afraid-guide-des-episodes",
    "x-default" => "#{ORIGIN}/series"
  }.freeze
  SET_PATHS = [ "/series", *EpisodeGuides::PATHS.values ].freeze

  setup { Rails.cache.clear }

  def tags = css_select('link[rel="alternate"][hreflang]')
  def alternates = tags.to_h { |n| [ n["hreflang"], n["href"] ] }

  test "the expected set is derived from the same table as the routes" do
    assert_equal EXPECTED, { "en" => "#{ORIGIN}#{EpisodeGuides::DEFAULT_PATH}" }
      .merge(EpisodeGuides::PATHS.transform_values { |p| "#{ORIGIN}#{p}" })
      .merge("x-default" => "#{ORIGIN}#{EpisodeGuides::DEFAULT_PATH}")
  end

  SET_PATHS.each do |path|
    test "#{path} emits exactly en, es, pt, fr and x-default, once each, in <head>" do
      get path
      assert_response :success
      assert_equal EXPECTED, alternates
      assert_equal 5, tags.size, "no duplicate hreflang tags"
      assert_equal 5, css_select('head link[rel="alternate"][hreflang]').size, "all inside <head>"
    end

    test "#{path} references itself" do
      get path
      assert_includes alternates.values, "#{ORIGIN}#{path}"
    end

    test "#{path}: every hreflang URL is absolute https on the canonical host with no query string" do
      get path
      alternates.each_value do |href|
        uri = URI.parse(href)
        assert_equal "https", uri.scheme, href
        assert_equal "www.nakedandafraidfan.com", uri.host, href
        assert_nil uri.query, href
        assert_nil uri.fragment, href
      end
    end

    test "#{path} on the production host: the self-referencing hreflang equals the page's canonical" do
      host! "www.nakedandafraidfan.com"
      https!
      get path
      assert_response :success
      canonical = css_select("link[rel=canonical]").first["href"]
      assert_equal "#{ORIGIN}#{path}", canonical
      assert_includes alternates.values, canonical
    end

    test "#{path} still emits the canonical-host set when reached on another host or with query params" do
      host! "nanda.herokuapp.com"
      get "#{path}?utm_source=x"
      assert_response :success
      assert_equal EXPECTED, alternates
    end
  end

  test "reciprocity: every page named by the set lists the same set back" do
    get "/series"
    set = alternates
    set.values.uniq.each do |url|
      get URI.parse(url).path
      assert_response :success, url
      assert_equal set, alternates, "#{url} must list the same set"
    end
  end

  test "en and x-default are the English /series page" do
    get "/series"
    assert_equal "#{ORIGIN}/series", alternates["en"]
    assert_equal alternates["en"], alternates["x-default"]
    assert_select "html[lang=en]"
  end

  test "each localized page declares its own html lang" do
    EpisodeGuides::PATHS.each do |lang, path|
      get path
      assert_select "html[lang=?]", lang
    end
  end

  test "no other public page emits hreflang" do
    series = Series.create!(name: "Hreflang Series")
    season = Season.create!(series: series, number: 1, year: 2020)
    pages = [
      "/", "/about", "/contact", "/shop", "/forum/guidelines", "/privacy_policy", "/terms_of_service",
      "/episodes", "/seasons", "/seasons/latest", "/survivors", "/items", "/locations",
      survivor_path(survivors(:one)), episode_path(episodes(:one)), item_path(items(:one)),
      series_path(series), season_path(season)
    ]
    pages.each do |path|
      get path
      assert_response :success, path
      assert_empty tags, "#{path} must not emit hreflang"
      assert_empty css_select('link[rel="alternate"]'), "#{path} must not emit any rel=alternate link"
    end
  end

  test "the sitemap carries no xhtml:link alternates (hreflang lives in the page head only)" do
    get "/sitemap.xml"
    assert_no_match(/hreflang/, response.body)
  end
end
