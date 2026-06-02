class BushcraftItem < ApplicationRecord
  has_paper_trail
  belongs_to :episode

  validates :item_type, presence: true

  def builder_ids=(values)
    super(Array(values).reject(&:blank?).map(&:to_i))
  end

  def builders
    Survivor.where(id: builder_ids) if builder_ids.present?
  end
end
