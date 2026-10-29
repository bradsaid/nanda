require "test_helper"

class PrivacyPolicyTest < ActionDispatch::IntegrationTest
  test "the policy renders and carries the Amazon Associates statement" do
    get privacy_policy_path
    assert_response :success
    assert_match(/As an Amazon Associate I earn from qualifying purchases\./, response.body)
    assert_select "#affiliate-links h3", /Affiliate links and the Shop/
    assert_select "#affiliate-links a[href=?]", shop_path
  end

  test "the policy tells visitors about affiliate tracking and retailer-hosted photos" do
    get privacy_policy_path
    assert_select "#affiliate-links", /Amazon Services LLC Associates Program/
    assert_select "#affiliate-links", /tracking ID/
    assert_select "#affiliate-links", /requests those images/
    assert_select "#affiliate-links", /no extra cost to you/
  end

  test "Amazon is listed among the third parties we share with" do
    get privacy_policy_path
    assert_select "li", /Affiliate program:.*Amazon Services LLC/m
  end

  test "the last-updated date reflects this revision" do
    get privacy_policy_path
    assert_select "em", /Last updated: October 29, 2026/
  end
end
