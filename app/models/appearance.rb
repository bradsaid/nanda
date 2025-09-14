class Appearance < ApplicationRecord
  belongs_to :survivor
  belongs_to :episode
  has_many :appearance_items, dependent: :destroy
  has_many :items, through: :appearance_items

  enum :result, { success: "success", tap_out: "tap_out", fail: "fail" }, prefix: true
  enum :role,   { duo: "duo", solo: "solo", xl_team: "xl_team", frozen: "frozen" }, prefix: true

  validates :starting_psr, :ending_psr, numericality: { allow_nil: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :days_lasted, numericality: { allow_nil: true, greater_than_or_equal_to: 0 }
end
