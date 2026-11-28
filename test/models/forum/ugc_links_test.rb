require "test_helper"

# Outbound links in forum posts carry rel="ugc nofollow noopener noreferrer", authors cannot
# supply their own rel/target, and our own links stay followable.
class Forum::UgcLinksTest < ActiveSupport::TestCase
  REL = "ugc nofollow noopener noreferrer".freeze

  setup do
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                  user: users(:one), title: "Links in posts")
  end

  def stored_html(body)
    @topic.posts.create!(user: users(:one), body: body).body_html.to_s
  end

  def links(html) = Nokogiri::HTML5.fragment(html).css("a[href]")

  def link_for(html, href) = links(html).find { |a| a["href"] == href }

  # --- save time: Forum::Post#render_html -----------------------------------------------

  test "a markdown link, an autolinked URL and a raw <a> all get the rel" do
    html = stored_html("[md](https://example.com/a) and https://example.org/b and <a href='http://example.net/c'>raw</a>")
    %w[https://example.com/a https://example.org/b http://example.net/c].each do |href|
      assert_equal REL, link_for(html, href)["rel"], href
    end
  end

  test "mailto, protocol-relative and uppercase-scheme links count as outbound" do
    html = stored_html(%(<a href="mailto:a@example.com">m</a> <a href="//cdn.example.com/x">p</a> <a href="HTTPS://Example.COM/y">u</a>))
    assert_equal REL, link_for(html, "mailto:a@example.com")["rel"]
    assert_equal REL, link_for(html, "//cdn.example.com/x")["rel"]
    assert_equal REL, link_for(html, "HTTPS://Example.COM/y")["rel"]
  end

  test "an author cannot choose the rel or the target" do
    html = stored_html(%(<a href="https://example.com/a" rel="dofollow" target="_blank" class="btn" style="x:y" onclick="evil()">x</a>))
    link = link_for(html, "https://example.com/a")
    assert_equal REL, link["rel"]
    assert_nil link["target"]
    assert_nil link["class"]
    assert_nil link["style"]
    assert_nil link["onclick"]
    assert_equal %w[href rel], link.attribute_nodes.map(&:name).sort
  end

  test "the sanitiser allowlist does not let authors supply rel, target, class, style or on* attributes" do
    allowed = Forum::Post::ALLOWED_ATTRIBUTES
    %w[rel target class style id onclick onerror].each { |attr| assert_not_includes allowed, attr }
  end

  test "links to this site are left alone, including look-alike-free relative and anchor links" do
    html = stored_html(%(<a href="/survivors/x">a</a> <a href="#post-1">b</a> <a href="https://www.nakedandafraidfan.com/episodes">c</a> <a href="https://nakedandafraidfan.com/items">d</a> <a href="?page=2">e</a>))
    %w[/survivors/x #post-1 https://www.nakedandafraidfan.com/episodes https://nakedandafraidfan.com/items ?page=2].each do |href|
      assert_nil link_for(html, href)["rel"], href
    end
  end

  test "look-alike hosts and userinfo tricks are outbound" do
    html = stored_html(%(<a href="https://www.nakedandafraidfan.com.evil.example/x">a</a> <a href="https://www.nakedandafraidfan.com@evil.example/y">b</a> <a href="https://evilnakedandafraidfan.com/z">c</a>))
    links(html).each { |a| assert_equal REL, a["rel"], a["href"] }
    assert_equal 3, links(html).size
  end

  test "javascript: links are still stripped, never rel-ed" do
    html = stored_html(%(<a href="javascript:alert(1)">x</a>))
    assert_empty links(html).select { |a| a["href"].to_s.start_with?("javascript") }
  end

  test "images are not links and stay as they were" do
    html = stored_html(%(<img src="https://example.com/a.png" alt="a">))
    assert_includes html, "https://example.com/a.png"
    assert_not_includes html, "rel="
  end

  # --- the module on its own -----------------------------------------------------------

  test "apply is idempotent and leaves link-free html byte-for-byte alone" do
    plain = "<p>No links <b>here</b> &amp; stuff</p>"
    assert_equal plain, Forum::UgcLinks.apply(plain)
    once = Forum::UgcLinks.apply(%(<a href="https://example.com">x</a>))
    assert_equal once, Forum::UgcLinks.apply(once)
  end

  test "apply overrides a pre-existing rel or target on outbound links" do
    html = Forum::UgcLinks.apply(%(<a href="https://example.com" rel="author" target="_blank">x</a>))
    link = links(html).first
    assert_equal REL, link["rel"]
    assert_nil link["target"]
  end

  test "apply handles nil, empty and malformed hrefs without raising" do
    assert_equal "", Forum::UgcLinks.apply(nil)
    assert_equal "", Forum::UgcLinks.apply("")
    html = Forum::UgcLinks.apply(%(<a href="http://exa mple.com/ bad">x</a> <a href="http://[::1">y</a> <a href="">z</a>))
    assert_equal REL, links(html).first["rel"]
  end
end
