require "test_helper"

# An episode synopsis must come out exactly as it was written, first letter included, on every
# surface that shows it: the page, the meta/OG descriptions, the Article JSON-LD, the series
# recap excerpts, and the admin edit form's save-and-reload round trip.
class EpisodeSynopsisTextTest < ActionDispatch::IntegrationTest
  FIRST_CHARS = [
    "In the wilds of Colombia, two survivalists look for water.",
    "On a small island, five strangers arrive.",
    "A team of two faces a flood.",
    "\u201CThe Olympics of Survival\u201D begins with fourteen survivors.",
    "Ann Alpha and Bo Beta return for a second challenge.",
    "Naked and Afraid XL returns with eight legends.",
    "*Legends* return to the jungle.",
    "\n\nA story that starts after a blank line.",
    "  Padded start with spaces.",
    "I survived the swamp.",
    "Fish & chips for two, say the \"locals\"."
  ].freeze

  setup do
    @series = Series.create!(name: "Naked and Afraid")
    @season = Season.create!(series: @series, number: 1, year: 2013)
    @loc    = Location.create!(country: "Colombia", region: "Choco", site: "Camp", latitude: 5.5, longitude: -76.7)
    @ann    = Survivor.create!(full_name: "Ann Alpha")
    @bo     = Survivor.create!(full_name: "Bo Beta")
    @n = 0
  end

  def episode(synopsis)
    Episode.create!(season: @season, number_in_season: (@n += 1), title: "Ep #{@n}", location: @loc, synopsis: synopsis).tap do |ep|
      Appearance.create!(episode: ep, survivor: @ann)
      Appearance.create!(episode: ep, survivor: @bo)
    end
  end

  # What a reader sees, with markup, blank lines and the *italic* markers removed.
  def visible(text) = text.to_s.delete("*").gsub(/<[^>]+>/, "").squish
  def json_ld = css_select('script[type="application/ld+json"]').flat_map { |n| p = JSON.parse(n.text); p.is_a?(Array) ? p : [ p ] }

  test "the synopsis card, meta descriptions and Article JSON-LD all start with the first letter written" do
    FIRST_CHARS.each do |syn|
      ep = episode(syn)
      get episode_path(ep)
      assert_response :success
      expected = visible(syn)

      card = css_select(".card").find { |c| c.at_css("h2")&.text&.strip == "Episode Synopsis" }.at_css(".card-body").text.squish
      assert_equal expected, card, "synopsis card for #{syn.inspect}"

      desc = css_select('meta[name="description"]').first["content"]
      assert_includes desc, expected.first(40), "meta description for #{syn.inspect}"
      og = css_select('meta[property="og:description"]').first["content"]
      assert og.start_with?(expected.first(40)), "og:description for #{syn.inspect}"

      article = json_ld.find { |s| s["@type"] == "Article" }
      assert_equal expected, article["articleBody"], "articleBody for #{syn.inspect}"
    end
  end

  test "Episode#synopsis_text never loses leading characters or double-escapes" do
    FIRST_CHARS.each do |syn|
      text = episode(syn).synopsis_text
      assert_not_includes text, "&amp;"
      assert_equal syn.delete("*").gsub(/<[^>]+>/, "").squish, text, syn.inspect
    end
  end

  test "series recap excerpts start with the first letter written" do
    ep = episode("In the wilds of Colombia, two survivalists look for water.")
    get series_path(@series)
    card = css_select("h3 a").find { |a| a.text == ep.title }.ancestors(".card").first
    assert_equal "In the wilds of Colombia, two survivalists look for water.", card.at_css("p.small").text.strip
  end

  test "saving a synopsis through the admin form and reloading keeps every character" do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    FIRST_CHARS.each do |syn|
      ep = episode(nil)
      patch admin_episode_path(ep), params: { episode: { synopsis: syn } }
      assert_redirected_to admin_episodes_path
      assert_equal syn, ep.reload.synopsis, "stored synopsis"

      # What a browser puts back into the textarea: the HTML parser drops ONE leading newline, so
      # Rails prepends one; the value submitted must equal the stored text.
      get edit_admin_episode_path(ep)
      raw = response.body[%r{<textarea[^>]*id="episode_synopsis"[^>]*>(.*?)</textarea>}m, 1]
      submitted = CGI.unescapeHTML(raw.sub(/\A\n/, ""))
      assert_equal syn, submitted, "textarea round trip"
    end
  end
end
