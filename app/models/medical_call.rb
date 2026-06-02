class MedicalCall < ApplicationRecord
  has_paper_trail
  belongs_to :episode
  belongs_to :survivor, optional: true
end
