require "test_helper"

# Every Amazon link we control outside the Shop carries our Associates tag.
class AffiliateLinksTest < ActionDispatch::IntegrationTest
  TAG = "nanda066f-20".freeze

  # The books page features these survivors by name.
  FEATURED = ["Ky Furneaux", "Shane Lewis", "Amber Shine", "Serena Shine", "Forrest Galante", "Laura Zerra",
              "Quince Mountain", "Alison Teal", "MaLu Beyonce"].freeze

  setup { FEATURED.each { |n| Survivor.create!(full_name: n) } }

  def with_tag(value = TAG)
    old = ENV["AMAZON_ASSOCIATE_TAG"]
    ENV["AMAZON_ASSOCIATE_TAG"] = value
    yield
  ensure
    ENV["AMAZON_ASSOCIATE_TAG"] = old
  end

  # --- ShopCatalog.tagged_url ----------------------------------------------

  test "tagged_url adds the tag to amazon.com links, however they are written" do
    assert_equal "https://www.amazon.com/dp/1646434277?tag=#{TAG}", ShopCatalog.tagged_url("https://www.amazon.com/dp/1646434277", tag: TAG)
    assert_equal "https://amazon.com/dp/1?tag=#{TAG}", ShopCatalog.tagged_url("https://amazon.com/dp/1", tag: TAG)
    assert_equal "http://www.amazon.com/dp/1?tag=#{TAG}", ShopCatalog.tagged_url("http://www.amazon.com/dp/1", tag: TAG)
    assert_equal "https://www.amazon.com/dp/1?th=1&tag=#{TAG}", ShopCatalog.tagged_url("https://www.amazon.com/dp/1?th=1", tag: TAG)
  end

  test "tagged_url leaves other hosts, tagged links and blank tags alone" do
    assert_equal "https://kyfurneaux.com/x", ShopCatalog.tagged_url("https://kyfurneaux.com/x", tag: TAG)
    assert_equal "https://notamazon.com/dp/1", ShopCatalog.tagged_url("https://notamazon.com/dp/1", tag: TAG)
    assert_equal "https://www.amazon.com/dp/1?tag=other-20", ShopCatalog.tagged_url("https://www.amazon.com/dp/1?tag=other-20", tag: TAG)
    assert_equal "https://www.amazon.com/dp/1", ShopCatalog.tagged_url("https://www.amazon.com/dp/1", tag: nil)
    assert_equal "https://www.amazon.com/dp/1", ShopCatalog.tagged_url("https://www.amazon.com/dp/1", tag: "")
  end

  test "tag_html_links tags and marks amazon anchors in stored HTML only" do
    html = %(Read <a href="https://www.amazon.com/dp/1775541762">The Wild Twins</a> or visit <a href="https://example.com/x">her site</a>.)
    out = ShopCatalog.tag_html_links(html, tag: TAG)
    assert_includes out, %(href="https://www.amazon.com/dp/1775541762?tag=#{TAG}")
    assert_includes out, %(rel="sponsored noopener noreferrer nofollow")
    assert_includes out, %(<a href="https://example.com/x">her site</a>)
    assert_equal "plain text", ShopCatalog.tag_html_links("plain text", tag: TAG)
  end

  # --- Podcasts & Books page -----------------------------------------------

  test "every Amazon link on the books page carries the tag and is marked sponsored" do
    with_tag do
      get podcasts_path
      assert_response :success
      links = css_select("a").select { |a| a["href"].to_s.include?("amazon.com") }
      assert_operator links.size, :>=, 12
      links.each do |a|
        assert_includes a["href"], "tag=#{TAG}", "untagged Amazon link: #{a['href']}"
        assert_match(/sponsored/, a["rel"].to_s)
        assert_match(/nofollow/, a["rel"].to_s)
      end
      assert_no_match(%r{a\.co/d/}, response.body)
    end
  end

  test "the books page carries the affiliate disclosure" do
    get podcasts_path
    assert_select ".shop-disclosure", /As an Amazon Associate I earn from qualifying purchases/
  end

  test "each book points at its own listing: the two Ky Furneaux books no longer share a link" do
    get podcasts_path
    hrefs = css_select("a").map { |a| a["href"].to_s }.select { |h| h.include?("amazon.com") }.map { |h| h[%r{/dp/(\w+)}, 1] }
    assert_equal hrefs.uniq.size, hrefs.size, "two books share one Amazon listing"
    assert_includes hrefs, "1646434277"   # Surviving the First 36 Hours
    assert_includes hrefs, "1646432428"   # FIRE
  end

  # --- Survivor bios ---------------------------------------------------------

  test "Amazon links in a survivor's bio are tagged and sponsored" do
    survivors(:one).update_columns(bio: %(Author of <a href="https://www.amazon.com/dp/1775541762">The Wild Twins</a> and <a href="https://example.com/b">a blog</a>.))
    with_tag do
      get survivor_path(survivors(:one))
      assert_response :success
      assert_select ".survivor-bio a[href=?]", "https://www.amazon.com/dp/1775541762?tag=#{TAG}" do |links|
        assert_match(/sponsored/, links.first["rel"])
      end
      assert_select ".survivor-bio a[href=?]", "https://example.com/b"
    end
  end

  test "a bio without Amazon links is untouched" do
    survivors(:one).update_columns(bio: "Plain bio with no links.")
    get survivor_path(survivors(:one))
    assert_select ".survivor-bio", /Plain bio with no links\./
  end

  # --- structured data -------------------------------------------------------

  test "the book structured data points at real product pages, not short links" do
    source = File.read(Rails.root.join("app/helpers/json_ld_helper.rb"))
    assert_no_match(%r{a\.co/d/}, source)
  end
end
