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

    when /knife|machete|sword|axe|tomahawk|hatchet|kukri|pulaski/
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
    when /tarp|duct|hammock|tent|mosquito|hide|fabric/
      self.item_type = "comfort item"  
    when /shovel/
      self.item_type = "digging tool"  
    else
      self.item_type = "other"
    end

  end

end