class Season < ApplicationRecord
  belongs_to :series
  has_many :episodes, dependent: :destroy

  validates :number, presence: true

  def continuous_story_effective?
    continuous_story || series.continuous_story
  end

end
