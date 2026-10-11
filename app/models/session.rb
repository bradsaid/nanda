class Session < ApplicationRecord
  # How long a sign-in stays valid. Matches the lifetime of the
  # forum_session_id cookie that carries the token (SessionsController#create).
  LIFETIME = 30.days

  belongs_to :user

  before_validation :generate_token, on: :create
  before_validation :set_expiry,     on: :create

  validates :token, presence: true, uniqueness: true

  # remembered_until used to be left NULL on every sign-in and NULL was treated
  # as "never expires", so a stolen token worked on the server forever even
  # though the browser cookie lapsed after 30 days. Rows written before that
  # was fixed still have a NULL, so they are honoured only for as long as the
  # cookie could have been alive, rather than being invalidated all at once.
  scope :active, -> {
    where("remembered_until > :now OR (remembered_until IS NULL AND created_at > :legacy_cutoff)",
          now: Time.current, legacy_cutoff: LIFETIME.ago)
  }

  def self.authenticate_by_token(token)
    return nil if token.blank?
    active.find_by(token: token)
  end

  private

  def generate_token
    return if token.present?
    self.token = loop do
      candidate = SecureRandom.urlsafe_base64(32)
      break candidate unless Session.exists?(token: candidate)
    end
  end

  def set_expiry
    self.remembered_until ||= LIFETIME.from_now
  end
end
