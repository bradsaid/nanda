require "test_helper"

class ItemSlugTest < ActiveSupport::TestCase
  test "the slug comes from the (lower-cased) name" do
    assert_equal "fire-starter", Item.create!(name: "Fire Starter").slug
    assert_equal "2-liter-bottle", Item.create!(name: "2 Liter Bottle").slug
    assert_equal "knife-machete", Item.create!(name: "Knife/Machete!").slug
  end

  test "two names that collapse to the same slug are told apart with -2" do
    a = Item.create!(name: "3 gallon bucket")
    b = Item.create!(name: "3-gallon bucket")
    assert_equal "3-gallon-bucket", a.slug
    assert_equal "3-gallon-bucket-2", b.slug
  end

  test "a purely numeric name cannot become a slug that reads as an id" do
    item = Item.create!(name: "1911")
    assert_equal "1911-item", item.slug
    assert_equal item, Item.friendly.find("1911-item")
  end

  test "a name with nothing sluggable still gets a slug" do
    assert_equal "item", Item.create!(name: "???").slug
    assert_equal "item-2", Item.create!(name: "!!!").slug
  end

  test "renaming follows the name and the old slug keeps resolving" do
    item = Item.create!(name: "Fire Starter")
    item.update!(name: "Ferro Rod")
    assert_equal "ferro-rod", item.reload.slug
    assert_equal item, Item.friendly.find("fire-starter")
    assert_equal item, Item.friendly.find("ferro-rod")
    assert_equal item, Item.friendly.find(item.id.to_s)
  end

  test "saving without renaming leaves the slug alone" do
    item = Item.create!(name: "Fire Starter")
    item.update!(item_type: "fire starting tool")
    assert_equal "fire-starter", item.reload.slug
  end

  test "to_param falls back to the id when there is no slug yet" do
    item = Item.create!(name: "Pot")
    item.update_columns(slug: nil)
    assert_equal item.id.to_s, item.reload.to_param
  end
end
