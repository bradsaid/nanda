# id -> slug for the models with a friendly_id slug (Episode, Item), for the few places
# that only have a record's numeric id in hand (a count keyed by item id, a pluck of
# [id, title]). Looking the slug up here means the link goes straight to the canonical
# URL instead of through the numeric-id 301. Read once per request (Current); the
# tables are a few hundred rows. A record with no slug yet (a half-migrated database)
# falls back to its id, which still resolves.
module RecordSlugs
  class << self
    def param(model, id)
      id = id.to_i
      slug = slug_for(model, id)
      slug.presence || id.to_s
    end

    private

    def slug_for(model, id)
      memoized = Current.record_slugs&.key?(model.name)
      slug = map_for(model)[id]
      return slug if slug || !memoized
      map_for(model, refresh: true)[id]
    end

    def map_for(model, refresh: false)
      Current.record_slugs ||= {}
      Current.record_slugs.delete(model.name) if refresh
      Current.record_slugs[model.name] ||= model.unscoped.where.not(slug: nil).pluck(:id, :slug).to_h
    end
  end
end
