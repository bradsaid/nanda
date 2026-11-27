require "test_helper"

class SurvivorQuickFactsTest < ActiveSupport::TestCase
  test "all quick facts are empty by default" do
    s = Survivor.create!(full_name: "Facts Default")
    assert_nil s.birth_year
    assert_nil s.hometown
    assert_nil s.nationality
    assert_not s.quick_facts?
  end

  test "birth year must be a plausible year and not in the future" do
    assert_not Survivor.new(full_name: "Too Old", birth_year: 1800).valid?
    assert_not Survivor.new(full_name: "Future", birth_year: Date.current.year + 1).valid?
    assert Survivor.new(full_name: "Fine", birth_year: 1985).valid?
    assert Survivor.new(full_name: "Blank", birth_year: nil).valid?
  end

  test "hometown and nationality are squished and blank becomes nil" do
    s = Survivor.create!(full_name: "Facts Tidy", hometown: "  Austin,   Texas ", nationality: "   ")
    assert_equal "Austin, Texas", s.hometown
    assert_nil s.nationality
  end

  test "the age is this year minus the birth year" do
    s = Survivor.new(full_name: "Aged", birth_year: 1985)
    assert_equal 30, s.approximate_age(Date.new(2015, 6, 1))
    assert_nil Survivor.new(full_name: "No Year").approximate_age
  end
end
