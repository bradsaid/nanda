require "test_helper"

class HeadMarkupTest < ActionDispatch::IntegrationTest
  def head_children(path = "/")
    get path
    assert_response :success
    Nokogiri::HTML(response.body).at_css("head").element_children
  end

  test "html declares lang=en" do
    get "/"
    assert_equal "en", Nokogiri::HTML(response.body).at_css("html")["lang"]
  end

  test "meta charset is the first element in head, ahead of the title" do
    kids = head_children
    assert_equal "meta", kids.first.name
    assert_equal "utf-8", kids.first["charset"]
    assert_operator kids.index { |e| e.name == "title" }, :>, 0
  end

  test "no meta keywords tag on any page, even where views still set content_for :keywords" do
    [ "/", "/about", "/survivors", "/episodes", "/items" ].each do |path|
      get path
      assert_empty css_select("meta[name=keywords]"), "meta keywords still emitted on #{path}"
    end
  end

  test "the png favicon is linked once" do
    get "/"
    pngs = css_select("head link[rel~=icon][href='/favicon.png']")
    assert_equal 1, pngs.size
    assert_equal 1, css_select("head link[rel~=icon][href='/icon.svg']").size
  end

  test "viewport, description and canonical are still present" do
    get "/"
    assert_equal 1, css_select("head meta[name=viewport]").size
    assert_equal 1, css_select("head meta[name=description]").size
    assert_equal 1, css_select("head link[rel=canonical]").size
  end

  test "static privacy and terms pages and the mailer layout declare lang=en" do
    [ "/privacy_policy", "/terms_of_service" ].each do |path|
      get path
      assert_equal "en", Nokogiri::HTML(response.body).at_css("html")["lang"], path
    end
    assert_match(/^html lang="en"/, Rails.root.join("app/views/layouts/mailer.html.slim").read)
  end

  test "every static error page declares lang, charset and noindex" do
    %w[400 404 422 500 406-unsupported-browser].each do |name|
      doc = Nokogiri::HTML(Rails.root.join("public/#{name}.html").read)
      assert_equal "en", doc.at_css("html")["lang"], name
      assert doc.at_css("meta[charset]"), "#{name}: charset"
      assert_match(/noindex/, doc.at_css("meta[name=robots]")&.[]("content").to_s, "#{name}: robots") unless name == "406-unsupported-browser"
    end
  end
end
