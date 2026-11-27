require "test_helper"

# config/regions.yml: every filming "country" the site lists (including the US states stored
# as a country) sits in exactly one region, and regions with no episodes do not exist.
class RegionsTest < ActiveSupport::TestCase
  # The by_country slugs in the live sitemap when the regions were written.
  LIVE_COUNTRIES = [
    "Alabama", "Alaska", "Argentina", "Arizona", "Australia", "Bahamas", "Belize", "Bolivia", "Botswana", "Brazil",
    "Bulgaria", "Cambodia", "Canada", "Colombia", "Colorado", "Costa Rica", "Croatia", "Dominica", "Ecuador", "Fiji",
    "Florida", "Georgia", "Guyana", "Honduras", "Illinois", "India", "Kentucky", "Louisiana", "Madagascar", "Malaysia",
    "Maldives", "Mexico", "Mississippi", "Montana", "Montserrat", "Mozambique", "Namibia", "New Mexico", "Nicaragua",
    "Panama", "Peru", "Philippines", "South Africa", "Tanzania", "Tennessee", "Texas", "Thailand", "Tobago", "Trinidad", "Zambia"
  ].freeze

  setup { NameSlugs.reset! }
  teardown { NameSlugs.reset! }

  test "every live filming country belongs to exactly one region" do
    LIVE_COUNTRIES.each do |country|
      regions = Regions.all.select { |r| r.country_keys.include?(country.downcase) }
      assert_equal 1, regions.size, "#{country} is in #{regions.map(&:name).inspect}"
    end
    mapped = Regions.all.flat_map(&:country_keys)
    assert_equal mapped.uniq, mapped, "a country is listed under two regions"
    assert_empty mapped - LIVE_COUNTRIES.map(&:downcase), "config lists a country that is not a live filming location"
  end

  test "the mapping decisions" do
    {
      "Georgia" => "North America", "Louisiana" => "North America", "Texas" => "North America", "Mexico" => "North America",
      "Canada" => "North America", "Australia" => "Oceania", "Fiji" => "Oceania", "Bulgaria" => "Europe", "Croatia" => "Europe",
      "Colombia" => "South America", "Guyana" => "South America", "Tobago" => "Central America & Caribbean",
      "Costa Rica" => "Central America & Caribbean", "Maldives" => "Asia", "South Africa" => "Africa"
    }.each { |country, region| assert_equal region, Regions.for_country(country)&.name, country }
    assert_nil Regions.for_country("Atlantis")
    assert_equal Regions.for_country("south africa"), Regions.for_country(" South Africa ")
  end

  test "region slugs are hyphenated and unique" do
    slugs = Regions.all.map(&:slug)
    assert_equal slugs.uniq, slugs
    assert_includes slugs, "africa"
    assert_includes slugs, "central-america-caribbean"
    assert slugs.all? { |s| s.match?(/\A[a-z0-9]+(-[a-z0-9]+)*\z/) }
  end

  test "find accepts the slug, other spellings of it and aliases" do
    assert_equal "africa", Regions.find("africa").slug
    assert_equal "africa", Regions.find("Africa").slug
    assert_equal "central-america-caribbean", Regions.find("Central America & Caribbean").slug
    assert_equal "central-america-caribbean", Regions.find("caribbean").slug
    assert_equal "central-america-caribbean", Regions.find("central-america").slug
    assert_nil Regions.find("atlantis")
    assert_nil Regions.find("")
  end

  test "summaries only include regions that have episodes, with their countries' counts" do
    names = Regions.summaries.map(&:name)
    assert_includes names, "Africa"                        # South Africa fixture episode
    assert_includes names, "Central America & Caribbean"   # Costa Rica fixture episode
    assert_not_includes names, "Asia"
    africa = Regions.summaries.find { |s| s.slug == "africa" }
    assert_equal [{ name: "South Africa", slug: "south-africa", episodes: 1 }], africa.countries
    assert_equal 1, africa.episode_count
  end
end
