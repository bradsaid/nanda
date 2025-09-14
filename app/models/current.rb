# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user

  # If you always want Current.user to come from Current.session.user:
  def user=(value)
    super
    self.session ||= OpenStruct.new(user: value)
  end
end
