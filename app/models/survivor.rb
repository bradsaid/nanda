# app/models/survivor.rb
class Survivor < ApplicationRecord
  has_many :appearances, dependent: :destroy
  has_many :episodes, through: :appearances
  has_many :appearance_items, through: :appearances

  has_one_attached :avatar   # <-- add this

  validates :full_name, presence: true, uniqueness: { case_sensitive: false }
end
