class Episode < ApplicationRecord
  belongs_to :season
  belongs_to :location

  has_many :appearances, dependent: :destroy
  has_many :survivors, through: :appearances

  validates :title, :number_in_season, presence: true
end
