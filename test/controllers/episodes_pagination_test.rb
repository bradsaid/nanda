require "test_helper"

class EpisodesPaginationTest < ActionDispatch::IntegrationTest
  PER = EpisodesController::SEASONS_PER_PAGE

  def canonical = css_select("link[rel=canonical]").first["href"]
  def season_ids_on_page = css_select("[id^=season-].card").map { |n| n["id"].delete_prefix("season-").to_i }

  # -------- /episodes (season overview) --------

  setup do
    @series = Series.create!(name: "Pager Series")
    @seasons = (1..(PER * 2 + 3)).map do |n|
      season = Season.create!(series: @series, number: n, year: 2000 + n)
      Episode.create!(season: season, number_in_season: 1, title: "Pager ep #{n}", air_date: Date.new(2000 + n, 1, 1), location: locations(:one))
      season
    end
  end

  test "the overview shows one page of seasons with a pagination nav" do
    get episodes_path
    assert_response :success
    assert_equal PER, season_ids_on_page.size
    assert_select "nav[aria-label=Pagination] li.page-item.active", text: "1"
    assert_select "a.page-link[rel=next][href=?]", "/episodes?page=2"
    assert_equal "http://www.example.com/episodes", canonical
  end

  test "page 2 canonicalises to ?page=2, page 1 to the clean URL" do
    get episodes_path(page: 2)
    assert_response :success
    assert_equal "http://www.example.com/episodes?page=2", canonical
    assert_equal canonical, css_select('meta[property="og:url"]').first["content"]
    assert_equal PER, season_ids_on_page.size
  end

  def pages = (Season.count.to_f / PER).ceil

  test "pages cover every season exactly once, in every sort" do
    [nil, "airdate", "newest"].each do |sort|
      seen = []
      (1..pages).each do |p|
        get episodes_path(sort: sort, page: (p if p > 1))
        assert_response :success, "sort=#{sort.inspect} page #{p}"
        seen.concat(season_ids_on_page)
      end
      assert_equal Season.count, seen.size, "sort=#{sort.inspect}"
      assert_equal seen.size, seen.uniq.size
    end
  end

  test "sort order holds across pages" do
    ids = []
    (1..pages).each { |p| get episodes_path(sort: "newest", page: (p if p > 1)); ids.concat(season_ids_on_page) }
    newest_first = Season.joins(:episodes).group("seasons.id").order(Arel.sql("MAX(episodes.air_date) DESC, seasons.id")).pluck("seasons.id")
    assert_equal newest_first.first(5), ids.first(5)
  end

  test "an out-of-range page is a 404 and a bad page value redirects" do
    last = (Season.count.to_f / PER).ceil
    get episodes_path(page: last)
    assert_response :success
    get episodes_path(page: last + 1)
    assert_response :not_found

    get "/episodes", params: { page: "abc" }
    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/episodes"
    get "/episodes?sort=newest&page=1"
    assert_redirected_to "http://www.example.com/episodes?sort=newest"
  end

  test "the jump menu lists every season; those on other pages link to their page" do
    get episodes_path
    options = css_select("select#season-jump option").reject { |o| o["value"].blank? }
    assert_equal Season.count, options.size
    on_this_page = options.select { |o| o["data-href"].blank? }
    assert_equal PER, on_this_page.size
    on_this_page.each { |o| assert css_select("##{o['value']}").any?, "#{o['value']} must exist on the page" }
    far = options.find { |o| o["value"] == "season-#{@seasons.last.id}" }
    assert_match %r{\A/episodes\?page=3#season-#{@seasons.last.id}\z}, far["data-href"]
  end

  test "the jump controller navigates to data-href when the season is not on the page" do
    js = Rails.root.join("app/javascript/controllers/season_jump_controller.js").read
    assert_includes js, "dataset.href"
  end

  test "the filtered location and season views are not paginated and ignore ?page" do
    get episodes_path(location_id: locations(:one).id, page: 9)
    assert_response :success
    assert_select "ul.pagination", false
    assert_equal "http://www.example.com/episodes?location_id=#{locations(:one).id}", canonical
    get episodes_path(season_id: @seasons.first.id, page: 9)
    assert_response :success
  end

  # -------- /episodes/by_country/:country --------

  test "country page paginates its cards, with the same crawlable nav and canonical rules" do
    per = EpisodesController::COUNTRY_BLOCKS_PER_PAGE
    place = Location.create!(country: "Pagerland", site: "Pager Site")
    count = per * 2 + 1
    count.times do |i|
      s = Season.create!(series: @series, number: 500 + i, year: 2010)
      Episode.create!(season: s, number_in_season: 1, title: "Country ep #{i}", air_date: Date.new(2010, 1, 1) + i, location: place)
    end

    get "/episodes/by_country/pagerland"
    assert_response :success
    assert_select ".card .card-header a[href^='/episodes/']", per
    assert_select "a.page-link[rel=next][href=?]", "/episodes/by_country/pagerland?page=2"
    assert_equal "http://www.example.com/episodes/by_country/pagerland", canonical
    first_page = css_select(".card-header a[href^='/episodes/']").map { |a| a["href"] }

    get "/episodes/by_country/pagerland", params: { page: 3 }
    assert_response :success
    assert_select ".card .card-header a[href^='/episodes/']", 1
    assert_equal "http://www.example.com/episodes/by_country/pagerland?page=3", canonical
    assert_empty(first_page & css_select(".card-header a[href^='/episodes/']").map { |a| a["href"] })

    get "/episodes/by_country/pagerland", params: { page: 4 }
    assert_response :not_found
  end

  test "a small country has no pagination nav and still lists everything" do
    quiet = Location.create!(country: "Quietland", site: "Quiet Site")
    Episode.create!(season: @seasons.first, number_in_season: 9, title: "Quiet ep", air_date: Date.new(2011, 1, 1), location: quiet)
    get "/episodes/by_country/quietland"
    assert_response :success
    assert_select ".card .card-header a[href^='/episodes/']", 1
    assert_select "ul.pagination", false
  end

  test "a country with no episodes is a 200 on page 1 and 404 beyond" do
    Location.create!(country: "Atlantis", site: "Sunken", latitude: 1.0, longitude: 1.0)
    get "/episodes/by_country/atlantis"
    assert_response :success
    assert_match(/No episodes found/, response.body)
    get "/episodes/by_country/atlantis", params: { page: 2 }
    assert_response :not_found
  end
end
