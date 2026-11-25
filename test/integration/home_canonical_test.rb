require "test_helper"

# The homepage lives at "/" only: /home permanently redirects there, and the
# canonical / og:url of the homepage is the bare root (with its trailing slash).
class HomeCanonicalTest < ActionDispatch::IntegrationTest
  test "/home permanently redirects to the root" do
    get "/home"
    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/"
  end

  test "/home keeps its query string when redirecting" do
    get "/home?utm_source=x"
    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/?utm_source=x"
  end

  test "homepage canonical and og:url are the root URL with a trailing slash" do
    get root_path
    assert_response :success
    assert_equal "http://www.example.com/", css_select("link[rel=canonical]").first["href"]
    assert_equal "http://www.example.com/", css_select('meta[property="og:url"]').first["content"]
  end

  test "nav links to the root, not /home" do
    get root_path
    assert_select "nav.site-nav a.nav-link", text: "Home" do |links|
      assert_equal "/#content", links.first["href"]
    end
    assert_select "a[href^='/home']", false
  end

  test "sitemap does not list /home" do
    Rails.cache.clear
    get "/sitemap.xml"
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    assert_includes locs, "https://www.nakedandafraidfan.com/"
    assert_not_includes locs, "https://www.nakedandafraidfan.com/home"
  end
end
