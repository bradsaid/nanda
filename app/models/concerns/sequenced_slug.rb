# Collision handling for friendly_id slugs: the next free "-2", "-3"... instead of
# friendly_id's default random UUID suffix, so a clash gives a readable URL that is the
# same on every database (and the backfill migration is deterministic).
#
# Include AFTER the `friendly_id` call so this wins over FriendlyId::Slugged's version.
module SequencedSlug
  extend ActiveSupport::Concern

  def resolve_friendly_id_conflict(candidates)
    base = candidates.first.to_s
    base = self.class.model_name.element if base.blank?
    n = 2
    n += 1 until slug_generator.available?("#{base}-#{n}")
    "#{base}-#{n}"
  end
end
