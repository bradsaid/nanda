class Item < ApplicationRecord

  has_many :appearance_items
  before_validation :normalize_name
  before_validation :set_item_type, if: :classify_needed?
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # The rules below used to be bare substring matches, and because they run in
  # order the first wrong hit won: "pan" matched "pants", "eel" matched
  # "steel", "ant" matched "plantain", "line" matched "clothesline". Short or
  # ambiguous words are now matched in one of two stricter ways:
  #
  #   word(...)   whole word, optional plural   ("axe", "axes" - not "taxed")
  #   suffix(...) end of a word, optional plural ("songbird", "walnut", "rawhide"
  #               still match; "nutrition", "minute" do not)
  #
  # Long, distinctive stems (knife, machete, snake, hammock...) stay as plain
  # substrings so compounds like "rattlesnake" and "slingshot" keep working.
  def self.word(*words)
    /\b(?:#{words.join("|")})(?:e?s)?\b/i
  end

  def self.suffix(*words)
    /(?:#{words.join("|")})(?:e?s)?\b/i
  end

  BLADE      = /knife|knives|machete|sword|tomahawk|hatchet|kukri|blade|pulaski|#{word("axe", "saw")}/i
  POT        = /pottery|#{word("pot", "pan")}/i
  FIRE       = /fire|lighter|flint|bow drill|#{word("lens")}/i
  HUNTING    = /\bbow\b|arrow(?!root)|sling|spear(?!mint)|atlatl|snare|blowgun|#{word("dart", "gun")}/i
  FISHING    = /fish|cast net|(?<!slack )#{word("line")}|#{word("cast", "hook", "mask", "fin", "net")}/i
  CORDAGE    = /paracord|cordage|clothesline|slack\s*line|twine|rope|string|#{word("cord")}/i
  COMFORT    = /tarp|hammock|mosquito|fabric|rawhide|#{word("duct", "tent", "hide", "pelt")}/i
  DIGGING    = /shovel/i
  COTTON     = /cotton/i
  CLOTHING   = /shirt|jacket|coat|pants|clothing/i
  CARPENTRY  = /hammer|chisel|mallet/i

  ANIMAL = Regexp.union(
    /snake|lizard|iguana|caiman|crocodile|alligator|turtle|tortoise|lobster|shrimp|mussel|oyster|
     piranha|tilapia|chicken|pigeon|parrot|rabbit|monkey|buffalo|bison|scorpion|spider|termite|
     beetle|cricket|grasshopper|octopus|squid|jellyfish|urchin|starfish|jaguar|leopard|coyote|
     hyena|insect|animal|shark|larvae|maggot|catfish|trout|snail|conch|wolf|wolves/ix,
    suffix("frog", "crab", "duck", "bird", "worm", "grub", "pig", "hog", "boar", "goat", "deer", "bug"),
    word("toad", "clam", "slug", "eel", "bass", "perch", "dove", "rat", "mouse", "mice", "cow",
         "elk", "moose", "ant", "ray", "puma", "lion", "bear", "fox", "goose", "geese")
  )

  PLANT = Regexp.union(
    /coconut|banana|mango|papaya|pineapple|guava|passion\s*fruit|jackfruit|breadfruit|berry|
     berries|fruit|cassava|potato|tuber|bamboo|cactus|aloe|mushroom|fungus|fungi|seaweed|kelp|
     algae|basil|cattail|lily\s*pad|lotus|flower|lentil|wood(?!land)|\bplant|\bherb|lea(?:f|ves)\b/ix,
    suffix("nut", "root", "corn", "bean", "seed", "tree", "vine", "bark", "grass", "grain", "mint"),
    word("yam", "taro", "palm", "sage", "rice", "reed")
  )

  # Maps an item name to its item_type. Order matters: the first rule that
  # matches wins, so more specific categories sit above broader ones.
  def self.classify(name)
    n = name.to_s
    return "other" if n.blank?

    case n
    when BLADE     then "blade"
    when POT       then "pot"
    when FIRE      then "fire starting tool"
    when HUNTING   then "hunting weapon"
    when FISHING   then "fishing tool"
    when CORDAGE   then "cordage"
    when COMFORT   then "comfort item"
    when DIGGING   then "digging tool"
    when COTTON    then "cotton"
    when CLOTHING  then "clothing"
    when CARPENTRY then "carpentry tool"
    when ANIMAL    then "animal"
    when PLANT     then "plant"
    else "other"
    end
  end

  private

  def normalize_name
    self.name = name.to_s.strip.downcase if name.present?
  end

  # Classify when the type is missing or the name changed. Running on every
  # validation overwrote any item_type that had been set or corrected by hand.
  def classify_needed?
    name.present? && (item_type.blank? || will_save_change_to_name?)
  end

  def set_item_type
    self.item_type = self.class.classify(name)
  end

end
