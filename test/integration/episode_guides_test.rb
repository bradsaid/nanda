require "test_helper"

class EpisodeGuidesTest < ActionDispatch::IntegrationTest
  LOCALE_FILES = EpisodeGuides::LANGS.index_with { |l| Rails.root.join("config/locales/landing_#{l}.yml") }
  # Present in only some languages (extra intro notes, the French "1er").
  OPTIONAL_KEYS = %w[intro_2 intro_3 date_first].freeze

  setup do
    Rails.cache.clear
    @series = Series.create!(name: "Guide Series")
    @season = Season.create!(series: @series, number: 7, year: 2023)
    @namibia = Location.create!(country: "Namibia", region: "Skeleton Coast", site: "Camp", latitude: -22.0, longitude: 14.0)
    Episode.create!(season: @season, number_in_season: 1, title: "Dunes", location: @namibia, air_date: Date.new(2023, 2, 2))
    Episode.create!(season: @season, number_in_season: 2, title: "Coast", location: @namibia, air_date: Date.new(2023, 2, 9))
  end

  def canonical = css_select("link[rel=canonical]").first["href"]
  def description = css_select('head meta[name="description"]').first["content"]
  def json_ld = css_select('script[type="application/ld+json"]').map { |n| JSON.parse(n.text) }.flatten
  def alternates = css_select('link[rel="alternate"][hreflang]').to_h { |n| [n["hreflang"], n["href"]] }

  def leaf_keys(hash, prefix = nil)
    hash.flat_map { |k, v| v.is_a?(Hash) && !(v.keys - %w[one other zero]).empty? ? leaf_keys(v, [prefix, k].compact.join(".")) : [[prefix, k].compact.join(".")] }
  end

  def guide_hash(lang)
    YAML.safe_load_file(LOCALE_FILES.fetch(lang)).dig(lang, "landing", "guide")
  end

  test "the route table, EpisodeGuides::PATHS and the named route helpers agree" do
    assert_equal "/es/naked-and-afraid-guia-de-episodios", episode_guide_es_path
    assert_equal "/pt/naked-and-afraid-guia-de-episodios", episode_guide_pt_path
    assert_equal "/fr/naked-and-afraid-guide-des-episodes", episode_guide_fr_path
    assert_equal EpisodeGuides::PATHS, { "es" => episode_guide_es_path, "pt" => episode_guide_pt_path, "fr" => episode_guide_fr_path }
  end

  EpisodeGuides::PATHS.each do |lang, path|
    test "#{lang}: renders 200 with the right lang attribute, title, h1 and canonical" do
      get path
      assert_response :success
      assert_select "html[lang=?]", lang
      assert_select "h1", count: 1, text: I18n.t("landing.guide.h1", locale: lang)
      assert_equal I18n.t("landing.guide.html_title", locale: lang), css_select("head title").first.text
      assert_equal "http://www.example.com#{path}", canonical
      assert_operator description.length, :<=, 160
      # Two fixture seasons/series plus this one: 3 seasons, 4 episodes, 3 series.
      expected = I18n.t("landing.guide.description", locale: lang,
                        seasons: I18n.t("landing.guide.seasons", locale: lang, count: 3),
                        episodes: I18n.t("landing.guide.episodes", locale: lang, count: 4),
                        series: I18n.t("landing.guide.series", locale: lang, count: 3))
      assert_equal expected, description
    end

    test "#{lang}: lists series, seasons, episode counts, years and countries, linking to the English season pages" do
      get path
      assert_select ".guide-series h2 a[href=?]", "/series/#{@series.id}", text: "Guide Series"
      assert_select ".guide-series a[href=?]", "/seasons/#{@season.id}", text: "#{I18n.t('landing.guide.table_season', locale: lang)} 7"
      row = css_select(".guide-series tbody tr").find { |tr| tr.text.include?("2023") }
      assert row, "season row with its year"
      cells = row.css("td").map { |td| td.text.strip }
      assert_equal ["2023", "2", "Namibia"], cells.drop(1)
    end

    test "#{lang}: FAQ is in the language and its JSON-LD matches the visible text" do
      get path
      faq = json_ld.find { |n| n["@type"] == "FAQPage" }
      assert_equal lang, faq["inLanguage"]
      assert_operator faq["mainEntity"].size, :>=, 2
      faq["mainEntity"].each do |q|
        assert_select "details summary", text: q["name"]
        assert_includes css_select("details").map(&:text).join(" ").squish, q["acceptedAnswer"]["text"]
      end
      assert_match(/3.*4.*3/, faq["mainEntity"].first["acceptedAnswer"]["text"])
      assert_equal "CollectionPage", json_ld.first["@type"]
      assert_equal lang, json_ld.first["inLanguage"]
    end

    test "#{lang}: the page and its alternates reference each other (hreflang symmetry)" do
      get path
      mine = alternates
      assert_equal %w[es pt fr x-default].sort, mine.keys.sort
      assert_equal "http://www.example.com/series", mine["x-default"]
      EpisodeGuides::PATHS.each { |l, p| assert_equal "http://www.example.com#{p}", mine[l] }
      # Self-reference, and every other language page lists exactly the same set.
      assert_equal "http://www.example.com#{path}", mine[lang]
      EpisodeGuides::PATHS.each_value do |other|
        get other
        assert_equal mine, alternates
      end
    end
  end

  test "unknown languages and mismatched slugs are 404" do
    get "/de/naked-and-afraid-guia-de-episodios"
    assert_response :not_found
    get "/es/naked-and-afraid-guide-des-episodes"
    assert_response :not_found
  end

  test "an empty database still renders each page" do
    AppearanceItem.delete_all
    Appearance.delete_all
    Episode.delete_all
    EpisodeGuides::PATHS.each_value do |path|
      get path
      assert_response :success
      assert_select "h1"
    end
  end

  test "English pages are unchanged: lang en, no hreflang alternates" do
    [ "/", "/series", "/episodes", "/seasons", "/seasons/latest", "/survivors" ].each do |path|
      get path
      assert_response :success
      assert_select "html[lang=en]", 1, "#{path} should stay lang=en"
      assert_empty css_select('link[rel="alternate"][hreflang]'), "#{path} should not carry hreflang tags"
    end
  end

  test "the global locale is untouched by a request" do
    get episode_guide_es_path
    assert_equal :en, I18n.default_locale
    assert_equal :en, I18n.locale
    assert_equal "Naked and Afraid: guía de episodios por temporada", I18n.t("landing.guide.html_title", locale: :es)
  end

  test "the three guide URLs are in the sitemap and linked from the footer" do
    get "/sitemap.xml"
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    EpisodeGuides::PATHS.each_value { |p| assert_includes locs, "https://www.nakedandafraidfan.com#{p}" }

    get "/"
    EpisodeGuides::PATHS.each do |lang, p|
      assert_select "footer a[href=?][hreflang=?]", p, lang
    end
  end

  test "translation files have the same keys and the same interpolations in every language" do
    base = guide_hash("es")
    keys = ->(h) { leaf_keys(h) - OPTIONAL_KEYS }
    EpisodeGuides::LANGS.each do |lang|
      assert_equal keys.(base).sort, keys.(guide_hash(lang)).sort, "#{lang} keys differ from es"
    end
    vars = ->(v) { v.is_a?(Hash) ? v.values.flat_map { |s| s.to_s.scan(/%\{(\w+)\}/) }.flatten.uniq.sort : v.to_s.scan(/%\{(\w+)\}/).flatten.uniq.sort }
    (keys.(base)).each do |key|
      next if key == "months"
      expected = vars.(base[key])
      EpisodeGuides::LANGS.each do |lang|
        assert_equal expected, vars.(guide_hash(lang)[key]), "#{lang}.#{key} interpolations differ"
      end
    end
    EpisodeGuides::LANGS.each { |l| assert_equal 12, guide_hash(l)["months"].size }
  end

  test "descriptions stay within 160 characters even with big numbers" do
    guide = EpisodeGuideData::Result.new(rows: [], season_count: 100, episode_count: 1000, series_count: 10, place_count: 40, top_places: [])
    EpisodeGuides::LANGS.each do |lang|
      assert_operator ApplicationController.helpers.episode_guide_description(guide, lang).length, :<=, 160, lang
    end
  end

  test "dates and lists use the page's language" do
    h = ApplicationController.helpers
    assert_equal "27 de noviembre de 2026", h.landing_date(Date.new(2026, 11, 27), lang: "es")
    assert_equal "27 de novembro de 2026", h.landing_date(Date.new(2026, 11, 27), lang: "pt")
    assert_equal "1er mars 2026", h.landing_date(Date.new(2026, 3, 1), lang: "fr")
    assert_equal "2 mars 2026", h.landing_date(Date.new(2026, 3, 2), lang: "fr")
    assert_equal "A, B y C", h.landing_list(%w[A B C], lang: "es")
    assert_equal "A et B", h.landing_list(%w[A B], lang: "fr")
  end

  test "the latest-season FAQ answer uses the most recent aired episode (the 2025 fixtures)" do
    travel_to Time.zone.local(2026, 11, 27, 12) do
      get episode_guide_es_path
      assert_includes css_select("details").map(&:text).join(" ").squish, "TestSeriesB Temporada 1"
      assert_includes response.body, "11 de septiembre de 2025"
    end
  end
end
