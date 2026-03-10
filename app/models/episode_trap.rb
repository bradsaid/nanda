class EpisodeTrap < ApplicationRecord
  belongs_to :episode
  has_many :food_sources, dependent: :nullify

  validates :trap_type, presence: true

  def label
    parts = [trap_type]
    parts << result if result.present?
    parts << "(#{notes})" if notes.present?
    parts.join(" - ")
  end

  def builder_ids=(values)
    super(Array(values).reject(&:blank?).map(&:to_i))
  end

  def builders
    Survivor.where(id: builder_ids) if builder_ids.present?
  end
end
