class Item < ApplicationRecord
  has_many :appearance_items
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end