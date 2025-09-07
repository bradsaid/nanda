class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  enum :role, { user: 0, admin: 1 }  # no _prefix
  # app/models/user.rb



  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
end