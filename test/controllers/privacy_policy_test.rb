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
    assert_select "em", /Last updated: November 1, 2026/
  end

  test "the policy has a forum accounts and community content section" do
    get privacy_policy_path
    assert_response :success
    assert_select "section#forum-accounts h2", /3\. Forum Accounts and Community Content/
    assert_select "section#forum-accounts", /Fan Forum/
    assert_select "section#forum-accounts", /Posts are public/
    assert_select "section#forum-accounts", /email address/
    assert_select "section#forum-accounts", /48 hours/
    assert_select "section#forum-accounts", /up to 4 images per post, 5 MB each/
    assert_select "section#forum-accounts", /Amazon S3/
    assert_select "section#forum-accounts", /bcrypt/
    assert_select "section#forum-accounts h3", /Reports and moderation/
    assert_select "section#forum-accounts h3", /Deleting your content and account/
  end

  test "the forum section links to the community guidelines and the contact options" do
    get privacy_policy_path
    assert_select "section#forum-accounts a[href=?]", forum_guidelines_path, text: "Community Guidelines"
    assert_select "section#forum-accounts a[href=?]", contact_path
    assert_select "section#forum-accounts a[href^=?]", "mailto:"
  end

  test "the stale contributors-only account wording is gone" do
    get privacy_policy_path
    assert_no_match(/only for editors and contributors/i, response.body)
    assert_no_match(/aggregated, non-identifying/i, response.body)
  end

  test "retention, sharing, cookies and children cover the forum" do
    get privacy_policy_path
    assert_select "section h2", /Data Retention/
    assert_select "li", /Forum accounts: kept while the account exists/
    assert_select "li", /Forum reports: kept for our moderation records/
    assert_select "li strong", /IP lookup/
    assert_select "li", /Email delivery:.*forum reply notifications/m
    assert_select "code", "forum_session_id"
    assert_select "code", "_vid"
    assert_select "section h2", /Children/
    assert_select "section", /forum and forum accounts are not intended for anyone under 13/
  end

  test "the affiliate click wording lists what is and is not stored" do
    get privacy_policy_path
    assert_select "#affiliate-links", /suspected-bot flag/
    assert_select "#affiliate-links", /No IP address, browser user-agent text, session, or account is stored/
    assert_select "#affiliate-links", /salted one-way hash of your IP address/
  end

  test "sections are numbered in order with no gaps" do
    get privacy_policy_path
    numbers = css_select("section > h2").map { |h| h.text[/\A(\d+)\./, 1].to_i }
    assert_equal (1..numbers.size).to_a, numbers
    assert_equal 15, numbers.size
  end

  test "no nested list is rendered as raw text" do
    get privacy_policy_path
    assert_no_match(/\bul\s+li\b/, css_select("body").text)
    assert_select "li ul", false, "the policy should not nest lists inside list items"
  end
end
