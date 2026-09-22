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

  test "plants show a dash since quantity is not tracked for them" do
    FoodSource.create!(episode: @episode, name: "coconut", category: "plant")
    get food_source_path("coconut")
    assert_select "td.text-end", text: "—"
  end
end
