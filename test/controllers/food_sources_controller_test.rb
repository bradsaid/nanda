require "test_helper"

class FoodSourcesControllerTest < ActionDispatch::IntegrationTest
  setup { @episode = episodes(:one) }

  # An animal with no recorded quantity means "unknown", not "zero". The
  # admin form says to leave it blank; the page then said 0.
  test "an unknown animal quantity shows as ? rather than 0" do
    FoodSource.create!(episode: @episode, name: "iguana", category: "animal", quantity: nil)
    get food_source_path("iguana")
    assert_response :success
    assert_select "td.text-end", text: "?"
    assert_select "td.text-end", text: "0", count: 0
  end

  test "a known animal quantity still shows the number" do
    FoodSource.create!(episode: @episode, name: "crab", category: "animal", quantity: 3)
    get food_source_path("crab")
    assert_select "td.text-end", text: "3"
  end

  test "a plant with a quantity shows the number" do
    FoodSource.create!(episode: @episode, name: "banana", category: "plant", quantity: 7)
    get food_source_path("banana")
    assert_select "td.text-end", text: "7"
  end

  test "plants without a quantity show a dash" do
    FoodSource.create!(episode: @episode, name: "coconut", category: "plant")
    get food_source_path("coconut")
    assert_select "td.text-end", text: "—"
  end

  # Rails reads everything after a dot as the format, so "mud crab. large" or
  # "st. john's wort" resolved to a truncated name and showed nothing.
  test "a name containing a dot is looked up whole" do
    FoodSource.create!(episode: @episode, name: "st. john's wort", category: "plant")
    get food_source_path("st. john's wort")
    assert_response :success
    assert_match(/john/i, response.body)
  end
end
