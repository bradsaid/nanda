class Session < ApplicationRecord
  belongs_to :user

  before_validation :generate_token, on: :create

  validates :token, presence: true, uniqueness: true

  scope :active, -> { where("remembered_until IS NULL OR remembered_until > ?", Time.current) }

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
end
