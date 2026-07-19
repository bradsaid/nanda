class AuthMailer < ApplicationMailer
  # 48-hour signed token from `generates_token_for :email_verification`.
  def verify_email(user)
    @user  = user
    @token = user.generate_token_for(:email_verification)
    @url   = email_verification_url(token: @token)
    mail subject: "Verify your Naked and Afraid Fan account", to: user.email_address
  end
end
