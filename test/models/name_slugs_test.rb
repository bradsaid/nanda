require "test_helper"

class NameSlugsTest < ActiveSupport::TestCase
  setup { NameSlugs.reset! }
  teardown { NameSlugs.reset! }

  # ---- the collision rule, with no database ----

  test "the plain slug goes to the first name in sorted order, the others get -2, -3" do
    slugs = NameSlugs.assign_slugs(["guinea-bissau", "guinea bissau", "guinea.bissau"], fallback: "country")
    assert_equal "guinea-bissau", slugs["guinea bissau"]   # sorts first
    assert_equal "guinea-bissau-2", slugs["guinea-bissau"]
    assert_equal "guinea-bissau-3", slugs["guinea.bissau"]
    assert_equal 3, slugs.values.uniq.size
  end

  test "a suffixed duplicate can never displace a name whose own slug looks like that suffix" do
    slugs = NameSlugs.assign_slugs(["foo", "foo!", "foo 2"], fallback: "country")
    assert_equal "foo-2", slugs["foo 2"]
    assert_equal "foo", slugs["foo"]
    assert_equal "foo-3", slugs["foo!"]
  end

  test "the result does not depend on the order the names arrive in" do
    names = ["a b", "a-b", "a.b", "A B!"]
    assert_equal NameSlugs.assign_slugs(names, fallback: "x"), NameSlugs.assign_slugs(names.reverse, fallback: "x")
  end

  test "a name with nothing sluggable falls back to the kind's word" do
    slugs = NameSlugs.assign_slugs(["???", "!!!"], fallback: "country")
    assert_equal %w[country country-2], slugs.values.sort
  end

  # ---- countries, from the locations table ----

  def country!(name) = Location.create!(country: name, site: "Slug Test", latitude: 1.0, longitude: 1.0)

  test "countries with unusual characters get clean slugs and resolve back to the stored name" do
    {
      "South Africa"       => "south-africa",
      "Côte d'Ivoire"      => "cote-d-ivoire",
      "St. Lucia"          => "st-lucia",
      "Bosnia & Herzegovina" => "bosnia-herzegovina",
      "Louisiana"          => "louisiana",       # a US state stored as the country
      "Guinea-Bissau"      => "guinea-bissau"
    }.each do |name, slug|
      country!(name)
      assert_equal slug, NameSlugs.slug(:country, name), name
      match = NameSlugs.resolve(:country, slug)
      assert_equal name, match.name, name
      assert_equal slug, match.slug
    end
  end

  test "old URL spellings resolve to the canonical slug: any case, spaces, plus signs, dots, accents" do
    country!("South Africa")
    country!("St. Lucia")
    country!("Côte d'Ivoire")
    ["South Africa", "south africa", "SOUTH AFRICA", "south+africa", "South_Africa", "South-Africa", "SOUTH-AFRICA"].each do |old|
      match = NameSlugs.resolve(:country, old)
      assert_equal "south-africa", match&.slug, old
    end
    assert_equal "st-lucia", NameSlugs.resolve(:country, "St. Lucia").slug
    assert_equal "cote-d-ivoire", NameSlugs.resolve(:country, "Cote d'Ivoire").slug   # typed without the accent
    assert_equal "cote-d-ivoire", NameSlugs.resolve(:country, "côte d'ivoire").slug
  end

  test "an unknown name or slug resolves to nil" do
    country!("Peru")
    assert_nil NameSlugs.resolve(:country, "atlantis")
    assert_nil NameSlugs.resolve(:country, "")
    assert_nil NameSlugs.resolve(:country, "peru-2")
  end

  test "case variants of one country are one country, shown by the commonest spelling" do
    country!("colombia")
    country!("Colombia")
    country!("Colombia")
    assert_equal 1, NameSlugs.all(:country).count { |_, slug| slug.start_with?("colombia") }
    assert_equal "Colombia", NameSlugs.resolve(:country, "colombia").name
    assert_equal "colombia", NameSlugs.resolve(:country, "colombia").key
  end

  test "two different countries that collapse to one slug are told apart, and both resolve" do
    country!("Guinea Bissau")
    country!("Guinea-Bissau")
    a = NameSlugs.slug(:country, "Guinea Bissau")
    b = NameSlugs.slug(:country, "Guinea-Bissau")
    assert_not_equal a, b
    assert_equal "guinea-bissau", a
    assert_equal "guinea-bissau-2", b
    assert_equal "Guinea Bissau", NameSlugs.resolve(:country, a).name
    assert_equal "Guinea-Bissau", NameSlugs.resolve(:country, b).name
    # the old URL of each still finds its own page
    assert_equal b, NameSlugs.resolve(:country, "guinea-bissau-2").slug
  end

  test "a country created after the mapping was memoized is still found" do
    country!("Peru")
    NameSlugs.slug(:country, "Peru")
    country!("Chile")
    assert_equal "chile", NameSlugs.resolve(:country, "Chile").slug
    assert_equal "chile", NameSlugs.slug(:country, "Chile")
  end

  # ---- the other kinds ----

  test "food sources, shelter types and item types use the same rules" do
    episode = episodes(:one)
    FoodSource.create!(episode: episode, name: "angel fish", category: "animal")
    FoodSource.create!(episode: episode, name: "st. john's wort", category: "plant")
    EpisodeShelter.create!(episode: episode, shelter_type: "Lean-to")
    EpisodeShelter.create!(episode: episode, shelter_type: "A-Frame (debris)")
    Item.create!(name: "flint rock", item_type: "fire starting tool")

    assert_equal "angel-fish", NameSlugs.slug(:food_source, "angel fish")
    assert_equal "st-john-s-wort", NameSlugs.slug(:food_source, "st. john's wort")
    assert_equal "st. john's wort", NameSlugs.resolve(:food_source, "st-john-s-wort").name
    assert_equal "angel-fish", NameSlugs.resolve(:food_source, "Angel Fish").slug

    assert_equal "lean-to", NameSlugs.slug(:shelter, "Lean-to")
    assert_equal "a-frame-debris", NameSlugs.slug(:shelter, "A-Frame (debris)")
    assert_equal "A-Frame (debris)", NameSlugs.resolve(:shelter, "a-frame-debris").name

    assert_equal "fire-starting-tool", NameSlugs.slug(:item_type, "fire starting tool")
    assert_equal "fire starting tool", NameSlugs.resolve(:item_type, "fire-starting-tool").name
  end

  test "slug of a name that is not in the data is its plain parameterized form, and a slug maps to itself" do
    assert_equal "never-seen", NameSlugs.slug(:country, "Never Seen")
    country!("South Africa")
    assert_equal "south-africa", NameSlugs.slug(:country, "south-africa")
  end
end
