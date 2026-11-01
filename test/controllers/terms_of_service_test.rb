require "test_helper"

class TermsOfServiceTest < ActionDispatch::IntegrationTest
  test "the terms render with the current revision date" do
    get terms_of_service_path
    assert_response :success
    assert_select "p", /Last updated: November 1, 2026/
  end

  test "the terms cover the shop: affiliate statement, no sales, best-effort data, no endorsement, safety" do
    get terms_of_service_path
    assert_select "#shop-terms h2", /Shop, Affiliate Links, and Third-Party Products/
    assert_select "#shop-terms", /As an Amazon Associate I earn from qualifying purchases\./
    assert_select "#shop-terms", /We do not sell anything/
    assert_select "#shop-terms", /no extra cost to you/
    assert_select "#shop-terms", /best-effort/
    assert_select "#shop-terms", /No endorsement/
    assert_select "#shop-terms", /Use gear safely and legally/
    assert_select "#shop-terms a[href=?]", privacy_policy_path
  end

  test "liability and product trademarks mention the shop, and sections are numbered in order" do
    get terms_of_service_path
    assert_select "li", /Products, retailers, or purchases made through links/
    assert_select "strong", text: "Products and Retailers:"
    numbers = css_select("h2").map { |h| h.text[/\A\d+/].to_i }
    assert_equal (1..numbers.size).to_a, numbers
  end
end
