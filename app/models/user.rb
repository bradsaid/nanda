class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :forum_topics,        class_name: "Forum::Topic",       dependent: :destroy
  has_many :forum_posts,         class_name: "Forum::Post",        dependent: :destroy
  has_many :forum_subscriptions, class_name: "Forum::Subscription", dependent: :destroy
  has_many :forum_reports_filed, class_name: "Forum::Report",       foreign_key: :reporter_id, dependent: :destroy

  enum :role, { user: 0, admin: 1, episode_editor: 2 }  # no _prefix

  attr_accessor :phone_number  # honeypot field on signup, never persisted

  before_save :downcase_email

  validates :password, length: { minimum: 8 }, if: :password_required?

  RESERVED_USERNAMES = %w[
    admin administrator moderator mod staff support root system
    bradsaid nanda naked afraid help contact api www null undefined
  ].freeze

  USERNAME_FORMAT = /\A[a-zA-Z0-9_]+\z/

  # Signed token used for password-reset / admin-invite emails. Invalidates
  # automatically when the password changes (because password_salt rotates),
  # and expires after 100 hours. Provides `user.password_reset_token` and
  # `User.find_by_password_reset_token!(token)`.
  generates_token_for :password_reset, expires_in: 100.hours do
    password_salt&.last(10)
  end

  # Signed token used for signup email verification. Expires after 48 hours.
  # Invalidates once `email_verified_at` is set, so a re-click is rejected.
  generates_token_for :email_verification, expires_in: 48.hours do
    email_verified_at&.to_i
  end

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, uniqueness: { case_sensitive: false },
                       length: { in: 3..20 },
                       format: { with: USERNAME_FORMAT, message: "may only contain letters, numbers, and underscores" },
                       allow_nil: true
  validate :username_not_reserved

  def username_not_reserved
    return if username.blank? || admin? || episode_editor?
    if RESERVED_USERNAMES.include?(username.to_s.downcase)
      errors.add(:username, "is reserved")
    end
  end

  scope :verified,   -> { where.not(email_verified_at: nil) }
  scope :banned,     -> { where.not(banned_at: nil) }
  scope :not_banned, -> { where(banned_at: nil) }

  def email_verified?
    email_verified_at.present? || admin? || episode_editor?
  end
  def banned?         = banned_at.present?

  private

  def downcase_email
    self.email_address = email_address.to_s.strip.downcase if email_address.present?
  end

  # Ask for password validation only when it's being set (create or change),
  # so admin edits that touch other fields don't force a password re-entry.
  def password_required?
    password.present? || password_confirmation.present? || password_digest.blank?
  end
end
