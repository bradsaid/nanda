class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  enum :role, { user: 0, admin: 1, episode_editor: 2 }  # no _prefix

  # Signed token used for password-reset emails. Invalidates automatically when
  # the password changes (because password_salt rotates), and expires after 15
  # minutes. Provides `user.password_reset_token` and
  # `User.find_by_password_reset_token!(token)`.
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
end