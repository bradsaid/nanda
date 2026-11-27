require "test_helper"

# Survivor page: "Also searched as" line, alternateName in Person JSON-LD, meta description,
# survivors search by alias, the admin form, and the optional Quick facts card with its FAQ
# entries and structured data (nothing renders for facts that are not filled in).
class SurvivorAliasesAndFactsTest < ActionDispatch::IntegrationTest
  setup do
    @survivor = Survivor.create!(full_name: "Allison Frueh")
    Appearance.create!(survivor: @survivor, episode: episodes(:one))
  end

  def description = css_select('head meta[name="description"]').first["content"]
  def json_ld = css_select('script[type="application/ld+json"]').map { |n| JSON.parse(n.text) }.flatten
  def person = json_ld.find { |n| n["@type"] == "Person" }
  def faq = json_ld.find { |n| n["@type"] == "FAQPage" }

  # ---- aliases ----

  test "no aliases: no 'Also searched as' line and no alternateName" do
    get survivor_path(@survivor)
    assert_response :success
    assert_select ".survivor-aliases", 0
    assert_nil person["alternateName"]
  end

  test "aliases show as a low-key line under the name and as alternateName in the Person JSON-LD" do
    @survivor.update!(aliases: ["Ally", "Ally Frueh"])
    get survivor_path(@survivor)
    assert_select "h1.survivor-name", "Allison Frueh"
    assert_select "p.survivor-aliases", text: "Also searched as: Ally, Ally Frueh"
    assert_equal ["Ally", "Ally Frueh"], person["alternateName"]
  end

  test "an alias identical to the name is not shown" do
    @survivor.update_columns(aliases: ["Allison Frueh", "Ally"])
    get survivor_path(@survivor)
    assert_select "p.survivor-aliases", text: "Also searched as: Ally"
  end

  test "aliases are woven into the generic meta description when it still fits in 160 characters" do
    @survivor.update!(aliases: ["Ally"])
    get survivor_path(@survivor)
    assert_equal "Profile for Allison Frueh (also searched as Ally): episodes, challenges, items brought/given, locations, and results.", description
    assert_operator description.length, :<=, 160
  end

  test "too many aliases leave the meta description exactly as before" do
    @survivor.update!(aliases: ["Ally Frueh", "Allison Wanderland", "Allison Freuh", "Alison Freuh", "Ally Freuh"])
    get survivor_path(@survivor)
    assert_equal "Profile for Allison Frueh: episodes, challenges, items brought/given, locations, and results.", description
  end

  test "a long bio keeps its first 160 characters; a short bio gets the aliases appended when they fit" do
    long = "word " * 80
    @survivor.update!(bio: long, aliases: ["Ally"])
    get survivor_path(@survivor)
    assert_equal long.squish.first(160), description

    @survivor.update!(bio: "A short bio.")
    get survivor_path(@survivor)
    assert_equal "A short bio. (Also searched as: Ally.)", description
  end

  test "the survivors search matches aliases, and a miss is still a miss" do
    @survivor.update!(aliases: ["Ally"])
    get survivors_path(q: "ally")
    assert_response :success
    assert_select "a[href=?]", survivor_path(@survivor)

    get survivors_path(q: "Allison")
    assert_select "a[href=?]", survivor_path(@survivor)

    get survivors_path(q: "zzzz-no-such")
    assert_select "a[href=?]", survivor_path(@survivor), 0
  end

  test "a survivor found by alias is also found when sorted another way" do
    @survivor.update!(aliases: ["Wanderland"])
    get survivors_path(q: "wanderland", sort: "name")
    assert_select "a[href=?]", survivor_path(@survivor)
  end

  # ---- admin form ----

  test "the admin form saves aliases (comma-separated, cleaned) and quick facts" do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    get edit_admin_survivor_path(@survivor)
    assert_response :success
    assert_select "input[name=?]", "survivor[aliases_text]"
    assert_select "input[name=?]", "survivor[birth_year]"
    assert_select "input[name=?]", "survivor[hometown]"
    assert_select "input[name=?]", "survivor[nationality]"

    patch admin_survivor_path(@survivor), params: { survivor: {
      aliases_text: " Ally , ally, Allison Wanderland ,, Allison Frueh", birth_year: "1985",
      hometown: " Austin,  Texas ", nationality: "American"
    } }
    assert_redirected_to admin_survivors_path
    @survivor.reload
    assert_equal ["Ally", "Allison Wanderland"], @survivor.aliases
    assert_equal 1985, @survivor.birth_year
    assert_equal "Austin, Texas", @survivor.hometown
    assert_equal "American", @survivor.nationality
  end

  test "the admin form refuses a future birth year" do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    patch admin_survivor_path(@survivor), params: { survivor: { birth_year: Date.current.year + 5 } }
    assert_response :unprocessable_entity
    assert_nil @survivor.reload.birth_year
  end

  test "the admin survivor list search matches aliases" do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    @survivor.update!(aliases: ["Zanzibar"])
    get admin_survivors_path(q: "zanzibar")
    assert_response :success
    assert_match "Allison Frueh", response.body
  end

  # ---- quick facts ----

  test "quick facts card always shows the computed facts but nothing about born/hometown/nationality until filled in" do
    get survivor_path(@survivor)
    assert_select "section.survivor-quick-facts" do
      assert_select "dt", text: "First appearance"
      assert_select "dt", text: "Episodes"
      assert_select "dt", text: "Born", count: 0
      assert_select "dt", text: "Hometown", count: 0
      assert_select "dt", text: "Nationality", count: 0
    end
    assert_nil person["birthDate"]
    assert_nil person["homeLocation"]
    assert_nil person["nationality"]
    questions = faq["mainEntity"].map { |q| q["name"] }
    assert questions.none? { |q| q =~ /How old|Where is|nationality/ }
  end

  test "filled-in facts appear in the card, the FAQ and the Person JSON-LD, in sync" do
    @survivor.update!(birth_year: 1985, hometown: "Austin, Texas", nationality: "American")
    age = Date.current.year - 1985
    get survivor_path(@survivor)

    assert_select "section.survivor-quick-facts" do
      assert_select "dt", text: "Born"
      assert_select "dd", text: "1985 (~#{age} years ago)"
      assert_select "dd", text: "Austin, Texas"
      assert_select "dd", text: "American"
    end

    assert_equal "1985", person["birthDate"]
    assert_equal({ "@type" => "Place", "name" => "Austin, Texas" }, person["homeLocation"])
    assert_equal({ "@type" => "Country", "name" => "American" }, person["nationality"])

    answers = faq["mainEntity"].to_h { |q| [q["name"], q["acceptedAnswer"]["text"]] }
    assert_match "born in 1985", answers["How old is Allison Frueh?"]
    assert_equal "Allison Frueh's listed hometown is Austin, Texas.", answers["Where is Allison Frueh from?"]
    assert_equal "Allison Frueh's listed nationality is American.", answers["What nationality is Allison Frueh?"]
    # Each JSON-LD question is visible on the page too.
    answers.each_key { |q| assert_select "details summary", text: q }
  end

  test "only the fields that are present produce a Q&A and a row" do
    @survivor.update!(hometown: "Austin, Texas")
    get survivor_path(@survivor)
    assert_select "dt", text: "Hometown"
    assert_select "dt", text: "Born", count: 0
    questions = faq["mainEntity"].map { |q| q["name"] }
    assert_includes questions, "Where is Allison Frueh from?"
    assert_not_includes questions, "How old is Allison Frueh?"
    assert_nil person["birthDate"]
  end

  test "existing FAQ entries are unchanged and still lead" do
    get survivor_path(@survivor)
    questions = faq["mainEntity"].map { |q| q["name"] }
    assert_equal "Which Naked and Afraid seasons has Allison Frueh appeared in?", questions.first
  end

  test "no fields exist for anything personal" do
    assert_empty Survivor.column_names & %w[ethnicity marital_status relationship_status spouse health alive deceased died_on religion]
  end
end
