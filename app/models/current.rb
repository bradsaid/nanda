# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user
  # Per-request memo for URL slug lookups (see NameSlugs and RecordSlugs).
  attribute :name_slug_mappings, :record_slugs

  # If you always want Current.user to come from Current.session.user:
  def user=(value)
    super
    self.session ||= Struct.new(:user).new(value)
  end
end
