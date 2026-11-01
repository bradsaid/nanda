require "test_helper"

class ForumGuidelinesTest < ActionDispatch::IntegrationTest
  teardown { ENV["FORUM_ENABLED"] = nil }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def enable_forum! = ENV["FORUM_ENABLED"] = "true"

  def make_topic
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Guidelines topic")
    post_record = topic.posts.create!(user: users(:one), body: "Opening post")
    [topic, post_record]
  end

  # ----- the page itself -----

  test "renders 200 logged out with the key headings, TL;DR and revision date" do
    enable_forum!
    get forum_guidelines_path
    assert_response :success
    assert_equal "/forum/guidelines", forum_guidelines_path
    assert_select "h1", /Community Guidelines/
    assert_select "#tldr h2", /short version/i
    assert_select "#tldr li", count: 5
    %w[Be\ respectful Privacy\ and\ safety Spoilers Stay\ on\ topic Facts,\ rumors\ and\ sources
       No\ spam\ or\ self-promotion Copyright\ and\ media Survival\ talk Your\ account
       How\ to\ report\ a\ post Moderation\ and\ appeals].each do |heading|
      assert_select "h2", text: heading
    end
    assert_select "time[datetime=?]", "2026-11-01", text: "November 1, 2026"
  end

  test "states the no-profanity rule in the short version, the respect section and moderation" do
    get forum_guidelines_path
    assert_select "#tldr li", count: 5
    assert_select "#tldr li", /Be respectful and keep it clean\.\s+No harassment and no profanity/
    assert_select "#respect", /No profanity or slurs, including censored or disguised versions like f\*\*\*/
    assert_select "#respect", /posts, topic titles, usernames and bios/
    assert_select "#respect", /Quoting the show isn't an exemption/
    assert_select "#respect", /mark it with asterisks or paraphrase it/
    assert_select "#moderation", /post with profanity may be edited or removed/
    assert_select "#moderation", /no automatic word filter/
  end

  test "the form reminders mention keeping it clean" do
    enable_forum!
    sign_in_as(users(:one))
    get new_forum_topic_path
    assert_select ".guidelines-callout-compact", /No profanity/
    topic, = make_topic
    get forum_topic_path(topic)
    assert_select ".guidelines-callout-compact", /No profanity/
    get forum_path
    assert_select ".guidelines-callout", /no profanity/
  end

  test "describes the real report flow and the real limits" do
    get forum_guidelines_path
    assert_select "#reporting", /Report/
    assert_select "#reporting", /Spam, Abuse, Off topic or Other/
    assert_select "#media", /up to #{Forum::Post::MAX_IMAGES_PER_POST} images/
    assert_select "#moderation", /#{Forum::PostsController::EDIT_WINDOW.in_minutes.to_i} minutes/
  end

  test "uses the existing disclaimer, affiliate disclosure and contact details" do
    get forum_guidelines_path
    assert_select "body", /not affiliated with, endorsed by, or sponsored by Discovery Communications/
    assert_select "#spam", /As an Amazon Associate I earn from qualifying purchases/
    assert_select "#spam a[href=?]", privacy_policy_path(anchor: "affiliate-links")
    assert_select "#moderation a[href=?]", "mailto:#{ApplicationController.helpers.contact_email_address}"
    assert_select "#moderation a[href=?]", contact_path
  end

  test "has a title, description, canonical URL and structured data" do
    get forum_guidelines_path
    assert_select "title", "Community Guidelines – Naked & Afraid Fan Forum"
    assert_select "meta[name=description][content*=?]", "Naked & Afraid fan forum"
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/forum/guidelines"
    assert_select "meta[property='og:url'][content=?]", "http://www.example.com/forum/guidelines"
    ld = css_select('script[type="application/ld+json"]').map { |n| JSON.parse(n.text) }
    page = ld.find { |s| s["@type"] == "WebPage" }
    assert_equal "http://www.example.com/forum/guidelines", page["url"]
    assert_equal "2026-11-01", page["dateModified"]
  end

  test "/guidelines redirects permanently to the page" do
    get "/guidelines"
    assert_response :moved_permanently
    assert_redirected_to "/forum/guidelines"
  end

  test "is served by the public static-pages controller, not the gated forum base" do
    assert_equal "static_pages", Rails.application.routes.recognize_path("/forum/guidelines")[:controller]
  end

  # ----- linked where it matters (forum on) -----

  test "forum index carries the callout and a Guidelines link, logged out" do
    enable_forum!
    get forum_path
    assert_response :success
    assert_select ".guidelines-callout a[href=?]", forum_guidelines_path
    assert_select "a.btn[href=?]", forum_guidelines_path, text: "Guidelines"
  end

  test "new-topic form links the guidelines and shows the agreement line" do
    enable_forum!
    sign_in_as(users(:one))
    get new_forum_topic_path
    assert_response :success
    assert_select ".guidelines-callout a[href=?]", forum_guidelines_path
    assert_select "p.guidelines-agreement", /By posting you agree to follow the Community Guidelines/
    assert_select "p.guidelines-agreement a[href=?]", forum_guidelines_path
  end

  test "reply form links the guidelines and shows the agreement line" do
    enable_forum!
    topic, = make_topic
    sign_in_as(users(:two))
    get forum_topic_path(topic)
    assert_response :success
    assert_select ".guidelines-callout a[href=?]", forum_guidelines_path
    assert_select "p.guidelines-agreement a[href=?]", forum_guidelines_path
  end

  test "report form links the guidelines" do
    enable_forum!
    _topic, opening = make_topic
    sign_in_as(users(:two))
    get new_forum_post_report_path(opening)
    assert_response :success
    assert_select "a[href=?]", forum_guidelines_path, text: "Community Guidelines"
  end

  test "sign-up page links the guidelines" do
    enable_forum!
    get signup_path
    assert_response :success
    assert_select "p.guidelines-agreement", /By creating an account you agree to follow the Community Guidelines/
    assert_select "p.guidelines-agreement a[href=?]", forum_guidelines_path
  end

  test "footer links the guidelines on any page" do
    enable_forum!
    get about_path
    assert_select "footer a[href=?]", forum_guidelines_path, text: "Community Guidelines"
  end

  test "terms of service point at the guidelines" do
    get terms_of_service_path
    assert_select "a[href=?]", forum_guidelines_path, text: "Community Guidelines"
  end

  # ----- forum flag off -----

  test "with the forum off, the page is still public and has no forum links" do
    get forum_guidelines_path
    assert_response :success
    assert_select "h1", /Community Guidelines/
    assert_select ".alert-info", /isn't open to the public yet/
    assert_select "a[href=?]", forum_path, count: 0
  end

  test "with the forum off, the footer hides the guidelines link and other pages still render" do
    get about_path
    assert_response :success
    assert_select "footer a[href=?]", forum_guidelines_path, count: 0
    get terms_of_service_path
    assert_response :success
  end

  test "with the forum off, sign-up still works and its guidelines link resolves" do
    get signup_path
    assert_response :success
    assert_select "p.guidelines-agreement a[href=?]", forum_guidelines_path
    get forum_guidelines_path
    assert_response :success
  end

  test "with the forum off, forum pages are still hidden from the public" do
    get forum_path
    assert_response :not_found
  end

  test "the forum promo banner does not crowd the guidelines page" do
    enable_forum!
    get forum_guidelines_path
    assert_select ".forum-promo", count: 0
    get about_path
    assert_select ".forum-promo"
  end

  test "the page stays public to a signed-in member, and the banner is gone once the forum is on" do
    enable_forum!
    sign_in_as(users(:one))
    get forum_guidelines_path
    assert_response :success
    assert_select ".alert-info", count: 0
    assert_select "a[href=?]", forum_path, text: "Back to the forum"
  end

  # ----- the spoiler fold the guidelines recommend really works -----

  test "the spoiler fold in the guidelines survives post rendering" do
    topic, = make_topic
    reply = topic.posts.create!(user: users(:two), body: "<details><summary>Spoiler</summary>Tap-out on day 12</details>")
    assert_includes reply.body_html, "<details>"
    assert_includes reply.body_html, "<summary>Spoiler</summary>"
    assert_includes reply.body_html, "Tap-out on day 12"
  end
end
