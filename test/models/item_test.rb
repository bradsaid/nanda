require "test_helper"

class ItemTest < ActiveSupport::TestCase
  # Names that the old substring rules got wrong, with what they should be.
  {
    "pants"                    => "clothing",   # was "pot": "pan" inside "pants"
    "underpants"               => "clothing",
    "purse"                    => "container",
    "plastic bottles"          => "container",
    "water bottle"             => "container",
    "sandals"                  => "clothing",
    "underwear"                => "clothing",
    "leather sandal"           => "clothing",
    "potato"                   => "plant",      # was "pot"
    "stainless steel"          => "other",      # was "animal": "eel" inside "steel"
    "steel"                    => "other",
    "steel pot"                => "pot",
    "plantain"                 => "plant",      # was "animal": "ant" inside "plantain"
    "canteen"                  => "other",      # was "animal"
    "gunny sack"               => "other",      # was "hunting weapon": "gun"
    "spearmint"                => "plant",      # was "hunting weapon": "spear"
    "clothesline"              => "cordage",    # was "fishing tool": "line"
    "slackline"                => "cordage",
    "slack line"               => "cordage",
    "mosquito net"             => "comfort item",  # "net" is a fishing word, but not here
    "fishing net"              => "fishing tool",
    "net"                      => "fishing tool"
  }.each do |name, expected|
    test "classifies #{name.inspect} as #{expected}" do
      assert_equal expected, Item.classify(name)
    end
  end

  # Things the old rules got right must keep working, including compounds that
  # only a substring (or end-of-word) match can catch.
  {
    "knife" => "blade", "machete" => "blade", "axe" => "blade", "folding saw" => "blade",
    "cooking pot" => "pot", "frying pan" => "pot",
    "ferro rod flint" => "fire starting tool", "bow drill" => "fire starting tool",
    "bow" => "hunting weapon", "slingshot" => "hunting weapon", "blowgun" => "hunting weapon",
    "fishing line" => "fishing tool", "fish hook" => "fishing tool", "cast net" => "fishing tool",
    "paracord" => "cordage", "bowstring" => "cordage", "rope" => "cordage",
    "tarp" => "comfort item", "rawhide" => "comfort item", "elk hide" => "comfort item",
    "shovel" => "digging tool", "cotton" => "cotton", "jacket" => "clothing", "hammer" => "carpentry tool",
    "rattlesnake" => "animal", "songbird" => "animal", "earthworm" => "animal", "wild boar" => "animal",
    "grub" => "animal", "ants" => "animal",
    "walnut" => "plant", "coconut" => "plant", "arrowroot" => "plant", "peppermint" => "plant",
    "lemongrass" => "plant", "bean" => "plant", "acorns" => "plant"
  }.each do |name, expected|
    test "still classifies #{name.inspect} as #{expected}" do
      assert_equal expected, Item.classify(name)
    end
  end

  test "an unknown or blank name is 'other'" do
    assert_equal "other", Item.classify("magic wand")
    assert_equal "other", Item.classify("")
    assert_equal "other", Item.classify(nil)
  end

  test "a new item is classified on save" do
    assert_equal "clothing", Item.create!(name: "  Pants ").item_type
    assert_equal "container", Item.create!(name: "Purse").item_type
    assert_equal "container", Item.create!(name: "Plastic Bottles").item_type
    assert_equal "clothing", Item.create!(name: "Sandals").item_type
  end

  test "a hand-set item_type survives later saves" do
    item = Item.create!(name: "sleeping mat")
    item.update!(item_type: "comfort item")

    item.update!(item_type: "comfort item")
    item.touch
    item.save!

    assert_equal "comfort item", item.reload.item_type
  end

  test "renaming an item reclassifies it" do
    item = Item.create!(name: "canteen")
    assert_equal "other", item.item_type

    item.update!(name: "frying pan")
    assert_equal "pot", item.reload.item_type
  end
end
