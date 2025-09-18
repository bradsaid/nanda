# app/models/appearance.rb
class Appearance < ApplicationRecord
  belongs_to :survivor
  belongs_to :episode
  has_many :appearance_items, dependent: :destroy
  has_many :items, through: :appearance_items

  # Convenience accessors
  has_one  :brought_ai,  -> { where(source: "brought") }, class_name: "AppearanceItem"
  has_one  :brought_item, through: :brought_ai,  source: :item

  has_many :given_ais,   -> { where(source: "given") },  class_name: "AppearanceItem"
  has_many :given_items,  through: :given_ais,  source: :item

  enum :result, { success: "success", tap_out: "tap_out", fail: "fail" }, prefix: true
  enum :role,   { duo: "duo", solo: "solo", xl_team: "xl_team", frozen: "frozen" }, prefix: true

  validates :starting_psr, :ending_psr, numericality: { allow_nil: true, in: 0..10 }
  validates :days_lasted, numericality: { allow_nil: true, greater_than_or_equal_to: 0 }
end
