# config/initializers/content_security_policy.rb
#
# script-src carries a per-request nonce (see the nonce settings at the bottom). The layout
# nonces the gtag.js loader, its inline config, the Funding Choices tags and the importmap
# scripts, so those run even without a host entry; the host entries below document what
# Google needs.
#
# `:https` is deliberately still in script-src/connect-src/img-src/style-src/font-src: the
# consent (Funding Choices) and ad scripts load further scripts from a changing set of
# Google hosts at runtime, and the nonce alone does not cover them (no 'strict-dynamic').
# Dropping `:https` from script-src needs a Report-Only run on production traffic first.
Rails.application.configure do
  config.content_security_policy do |p|
    p.default_src :self
    p.script_src  :self, :https,
                  'https://www.googletagmanager.com',
                  'https://www.google-analytics.com',
                  'https://analytics.google.com',
                  'https://fundingchoicesmessages.google.com',
                  'https://pagead2.googlesyndication.com',
                  'https://googleads.g.doubleclick.net'
    p.style_src   :self, :https, :unsafe_inline
    p.img_src     :self, :https, :data,
                  'https://www.google-analytics.com',
                  'https://www.googletagmanager.com',
                  'https://www.google.com'
    p.frame_src   :self,
                  'https://www.googletagmanager.com',
                  'https://fundingchoicesmessages.google.com',
                  'https://googleads.g.doubleclick.net',
                  'https://www.google.com'
    p.font_src    :self, :https, :data
    p.connect_src :self, :https,
                  'https://www.googletagmanager.com',
                  'https://www.google-analytics.com',
                  'https://region1.google-analytics.com',
                  'https://analytics.google.com',
                  'https://region1.analytics.google.com',
                  'https://www.google.com',
                  'https://stats.g.doubleclick.net',
                  'https://fundingchoicesmessages.google.com',
                  'https://pagead2.googlesyndication.com'

  end
end

# Keep these (do NOT hardcode a nonce string)
Rails.application.config.content_security_policy_nonce_generator  = ->(_req) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

