class User < ApplicationRecord
  BIO_MAX_LEN = 500

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :forum_topics,        class_name: "Forum::Topic",       dependent: :destroy
  has_many :forum_posts,         class_name: "Forum::Post",        dependent: :destroy
  has_many :forum_subscriptions, class_name: "Forum::Subscription", dependent: :destroy
  has_many :forum_reports_filed, class_name: "Forum::Report",       foreign_key: :reporter_id, dependent: :destroy
  # Both columns carry an FK but no dependent: rule, so destroying a user who
  # had left the last reply on a surviving topic (or had handled a report)
  # raised PG::ForeignKeyViolation. Nullify instead — the views already treat
  # a missing last_post_user / handled_by as "unknown".
  has_many :forum_topics_last_posted, class_name: "Forum::Topic",  foreign_key: :last_post_user_id, dependent: :nullify
  has_many :forum_reports_handled,    class_name: "Forum::Report", foreign_key: :handled_by_id,     dependent: :nullify
  has_one_attached :avatar do |attachable|
    # Small round avatar beside a poster's name on every post.
    attachable.variant :chip, resize_to_fill: [64, 64], saver: { quality: 80, strip: true }
  end

  validates :bio, length: { maximum: BIO_MAX_LEN }, allow_blank: true
  validate  :avatar_within_limits

  def avatar_within_limits
    return unless avatar.attached?
    errors.add(:avatar, "must be an image") unless avatar.blob.content_type.to_s.start_with?("image/")
    errors.add(:avatar, "must be under 5 MB") if avatar.blob.byte_size > 5.megabytes
  end

  # forum_tester grants nothing except visibility of the forum while
  # FORUM_ENABLED is unset (see ApplicationController#forum_preview_access?).
  # It is deliberately NOT part of admin_signed_in?, so these accounts get no
  # /admin access, no forum moderation powers, and no admin redirect on login.
  enum :role, { user: 0, admin: 1, episode_editor: 2, forum_tester: 3 }  # no _prefix

  attr_accessor :phone_number  # honeypot field on signup, never persisted

  # before_validation, not before_save: uniqueness runs during validation, so
  # normalising afterwards let "Foo@x.com" pass the check against a stored
  # "foo@x.com" and only collide at the database index.
  before_validation :downcase_email
  before_validation :downcase_pending_email

  validates :pending_email_address,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            allow_nil: true
  validate  :pending_email_not_already_taken

  # Every lookup by address must go through this. The column is a plain
  # string holding a lowercased address, so find_by(email_address:) misses
  # anyone who types their own address with different capitalisation.
  def self.find_by_email(address)
    return nil if address.blank?
    find_by(email_address: address.to_s.strip.downcase)
  end

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

  # Confirms a requested email change. Keyed on the pending address, so the
  # link dies the moment the request is cancelled or superseded, and expires
  # after 24 hours.
  generates_token_for :email_change, expires_in: 24.hours do
    pending_email_address
  end

  # Signed token used for signup email verification. Expires after 48 hours.
  # Invalidates once `email_verified_at` is set, so a re-click is rejected.
  generates_token_for :email_verification, expires_in: 48.hours do
    email_verified_at&.to_i
  end

  validates :email_address, presence: true, uniqueness: { case_sensitive: false },
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

  # Moves the confirmed address into place. The new address arrived by a link
  # sent to it, so it counts as verified.
  def apply_pending_email!
    return false if pending_email_address.blank?
    update!(email_address: pending_email_address,
            pending_email_address: nil,
            email_verified_at: Time.current)
  end

  # Mirrors #email_verified?: staff count as verified whatever the column
  # says, because they are created without going through the email flow.
  # Keep these two in step — a count that disagrees with the badge beside it
  # is worse than no count.
  STAFF_ROLES = %i[admin episode_editor].freeze

  scope :verified,   -> { where.not(email_verified_at: nil).or(where(role: STAFF_ROLES.map { |r| roles[r] })) }
  scope :unverified, -> { where(email_verified_at: nil).where.not(role: STAFF_ROLES.map { |r| roles[r] }) }
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

  def downcase_pending_email
    self.pending_email_address = pending_email_address.to_s.strip.downcase.presence
  end

  def pending_email_not_already_taken
    return if pending_email_address.blank?
    if pending_email_address == email_address
      errors.add(:pending_email_address, "is already your address")
    elsif User.where.not(id: id).exists?(email_address: pending_email_address)
      errors.add(:pending_email_address, "is already in use")
    end
  end

  # Ask for password validation only when it's being set (create or change),
  # so admin edits that touch other fields don't force a password re-entry.
  def password_required?
    password.present? || password_confirmation.present? || password_digest.blank?
  end
end
