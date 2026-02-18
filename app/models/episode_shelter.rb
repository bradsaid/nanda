class EpisodeShelter < ApplicationRecord
  belongs_to :episode

  validates :shelter_type, presence: true
end
