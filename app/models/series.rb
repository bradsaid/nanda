class Series < ApplicationRecord
  has_many :seasons, dependent: :destroy
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
