require "test_helper"

class SurvivorsPaginationTest < ActionDispatch::IntegrationTest
  PER = SurvivorsController::PER_PAGE

  setup do
    # Fixtures hold 2 survivors; this makes 3 pages in every sort.
    (1..(PER * 2 + 10)).each { |i| Survivor.create!(full_name: format("Pager %03d Person", i)) }
    Rails.cache.clear
  end

  def canonical = css_select("link[rel=canonical]").first["href"]
  def cards     = css_select("#survivors-results a.card")
  def names     = css_select("#survivors-results .survivor-name-stack").map { |n| [n.at_css(".first-name").text, n.at_css(".last-name").text].join(" ") }

  test "page 1 renders one page of cards with a bootstrap pagination nav" do
    get survivors_path
    assert_response :success
    assert_equal PER, cards.size
    assert_select "nav[aria-label=Pagination] ul.pagination li.page-item.active", text: "1"
    assert_select "nav[aria-label=Pagination] a.page-link[rel=next][href^=?]", "/survivors?page=2"
    assert_select "nav[aria-label=Pagination] a.page-link[rel=prev]", false
    assert_equal "http://www.example.com/survivors", canonical
  end

  test "page 2 canonicalises to ?page=2 and shows different survivors than page 1" do
    get survivors_path
    page1 = names
    get survivors_path(page: 2)
    assert_response :success
    assert_equal "http://www.example.com/survivors?page=2", canonical
    assert_equal canonical, css_select('meta[property="og:url"]').first["content"]
    assert_equal PER, cards.size
    assert_empty(page1 & names)
    assert_select "a.page-link[rel=prev]"
    assert_select "a.page-link[rel=next]"
  end

  test "the last page holds the remainder and a page past it is a 404" do
    total = Survivor.count
    last  = (total.to_f / PER).ceil
    get survivors_path(page: last)
    assert_response :success
    assert_equal total - (last - 1) * PER, cards.size
    assert_select "a.page-link[rel=next]", false

    get survivors_path(page: last + 1)
    assert_response :not_found
  end

  test "invalid page values redirect to the clean URL, keeping sort and q" do
    %w[abc 0 -2 1 02].each do |bad|
      get "/survivors", params: { page: bad }
      assert_response :moved_permanently, bad
      assert_redirected_to "http://www.example.com/survivors"
    end
    get "/survivors?sort=name&q=Pager&page=0"
    assert_redirected_to "http://www.example.com/survivors?q=Pager&sort=name"
  end

  test "every sort paginates, and pages concatenate to the whole sorted list without repeats" do
    %w[challenges episodes name popular newest oldest recent].each do |sort|
      seen = []
      (1..3).each do |p|
        get survivors_path(sort: sort, page: (p if p > 1))
        assert_response :success, "#{sort} page #{p}"
        seen.concat(names)
        # Sort and page links are preserved in the pagination links.
        assert_select "a.page-link[href*='sort=#{sort}']" if p == 1 && sort != "challenges"
      end
      assert_equal Survivor.count, seen.size, sort
      assert_equal seen.uniq.size, seen.size, "#{sort}: a survivor appeared on two pages"
    end
  end

  test "A-Z sort is alphabetical across pages" do
    all = []
    (1..3).each do |p|
      get survivors_path(sort: "name", page: (p if p > 1))
      all.concat(names)
    end
    assert_equal Survivor.order(:full_name, :id).pluck(:full_name), all
  end

  test "A-Z letter links lead to the page each letter starts on" do
    Survivor.create!(full_name: "Zed Zulu")
    get survivors_path(sort: "name")
    z_link = css_select("nav.survivor-az a").find { |a| a.text.strip == "Z" }
    assert z_link, "Z is on a later page but must still be linked"
    assert_match(%r{\A/survivors\?.*page=3.*#az-Z\z}, z_link["href"])
    a_link = css_select("nav.survivor-az a").find { |a| a.text.strip == "P" }
    assert_equal "#az-P", a_link["href"], "a letter that starts on this page is an in-page anchor"
    assert_equal 1, css_select("#az-P").size

    get z_link["href"].sub(/#.*/, "")
    assert_equal 1, css_select("#az-Z").size, "the anchor exists on the page the link leads to"
  end

  test "popular sort ranks by page views across pages" do
    last = Survivor.order(:full_name, :id).last
    3.times { PageView.create!(path: "/survivors/#{last.slug}") }
    get survivors_path(sort: "popular")
    assert_equal last.full_name, names.first, "the most viewed survivor leads page 1 even though A-Z puts them last"
    get survivors_path(sort: "popular", page: 2)
    assert_response :success
    assert_not_includes names, last.full_name
  end

  test "search paginates server-side and keeps q in the page links" do
    get survivors_path(q: "Pager")
    assert_response :success
    assert_equal PER, cards.size
    assert_select "meta[name=robots][content=?]", "noindex, follow"
    assert_select "a.page-link[rel=next][href*='q=Pager']"
    assert_equal "http://www.example.com/survivors", canonical

    get survivors_path(q: "Pager", page: 3)
    assert_response :success
    assert_equal 10, cards.size
  end

  test "a search with a single match still shows it and has no pagination nav" do
    get survivors_path(q: "Pager 007")
    assert_response :success
    assert_equal ["Pager 007 Person"], names
    assert_select "ul.pagination", false
  end

  test "a search with no results is a 200 on page 1 and a 404 beyond" do
    get survivors_path(q: "zzzznomatch")
    assert_response :success
    assert_match(/No survivors found/, response.body)
    get survivors_path(q: "zzzznomatch", page: 2)
    assert_response :not_found
  end

  test "structured data is still emitted" do
    get survivors_path
    ld = css_select('script[type="application/ld+json"]').flat_map { |n| [JSON.parse(n.text)].flatten }
    list = ld.find { |s| s.is_a?(Hash) && s["@type"] == "ItemList" }
    assert list
    assert_operator list["itemListElement"].size, :>, 0
  end

  test "page weight stays small: 48 cards per page" do
    get survivors_path
    assert_operator response.body.bytesize, :<, 120_000
  end
end
