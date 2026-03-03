class Item < ApplicationRecord

  has_many :appearance_items
  before_validation :normalize_name
  before_validation :set_item_type
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  private

  def normalize_name
    self.name = name.to_s.strip.downcase if name.present?
  end

  def set_item_type
    return if name.blank?

    case name

    when /knife|machete|sword|axe|saw|tomahawk|hatchet|kukri|blade|pulaski/
      self.item_type = "blade"
    when /pot|pan|pottery/
      self.item_type = "pot"
    when /fire|lighter|flint|bow drill|lens/
      self.item_type = "fire starting tool"
     when /\bbow\b|arrow|sling|spear|gun|atlatl|snare|dart/
      self.item_type = "hunting weapon"
    when /fish|cast|hook|line|mask|fins/
      self.item_type = "fishing tool"
    when /cord|rope|string/
      self.item_type = "cordage"
    when /tarp|duct|hammock|tent|mosquito|hide|pelt|fabric/
      self.item_type = "comfort item"
    when /shovel/
      self.item_type = "digging tool"
    when /snake|lizard|iguana|caiman|crocodile|alligator|turtle|tortoise|frog|toad|
          crab|lobster|shrimp|clam|mussel|oyster|snail|slug|conch|
          fish|eel|catfish|piranha|trout|bass|tilapia|perch|
          bird|chicken|duck|goose|pigeon|dove|parrot|
          pig|boar|hog|deer|goat|rabbit|rat|mouse|monkey|
          cow|buffalo|bison|elk|moose|
          scorpion|spider|ant|termite|beetle|cricket|grasshopper|worm|grub|larvae|maggot|
          shark|ray|octopus|squid|jellyfish|urchin|starfish|
          jaguar|puma|leopard|lion|bear|wolf|fox|coyote|hyena|
          insect|bug|animal/x
      self.item_type = "animal"
    when /coconut|banana|mango|papaya|pineapple|guava|passion\s*fruit|jackfruit|breadfruit|
          berry|berries|fruit|
          yam|taro|cassava|potato|tuber|root|
          bamboo|palm|cactus|aloe|
          mushroom|fungus|fungi|
          seaweed|kelp|algae|
          herb|mint|basil|sage|
          plant|leaf|leaves|bark|vine|seed|nut|grain|corn|rice|bean|lentil|
          tree|wood(?!land)|flower|grass|reed|cattail|lily\s*pad|lotus/x
      self.item_type = "plant"
    else
      self.item_type = "other"
    end

  end

end