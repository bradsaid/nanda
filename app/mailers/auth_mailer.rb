class AuthMailer < ApplicationMailer
  # 48-hour signed token from `generates_token_for :email_verification`.
  # Heads-up to the site owner whenever someone registers. Sent to
  # CONTACT_EMAIL, the same address the contact form and forum reports use.
  def new_signup(user)
    @user = user
    @directory_url = admin_forum_users_url
    @profile_url   = user.username.present? ? forum_profile_url(username: user.username) : nil
    mail subject: "[signup] #{user.username.presence || user.email_address}",
         to: ENV.fetch("CONTACT_EMAIL", "brad@nakedandafraidfan.com")
  end

  # Sent to the NEW address. Clicking the link is what actually applies the
  # change, so an address nobody controls can never take over an account.
  def confirm_email_change(user)
    @user  = user
    @token = user.generate_token_for(:email_change)
    @url   = email_change_url(token: @token)
    mail subject: "Confirm your new email address", to: user.pending_email_address
  end

  # Sent to the CURRENT address, so a change requested by someone else does
  # not happen quietly.
  def email_change_requested(user)
    @user = user
    mail subject: "Someone requested an email change on your account",
         to: user.email_address
  end

  def verify_email(user)
    @user  = user
    @token = user.generate_token_for(:email_verification)
    @url   = email_verification_url(token: @token)
    mail subject: "Verify your Naked and Afraid Fan account", to: user.email_address
  end
end
