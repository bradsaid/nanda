# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |p|
    p.default_src :self
    p.script_src  :self, :https, 'https://www.googletagmanager.com', 'https://www.google-analytics.com', 'https://analytics.google.com'
    p.style_src   :self, :https, :unsafe_inline
    p.img_src     :self, :https, :data, 'https://www.google-analytics.com'
    p.frame_src   :self, 'https://www.googletagmanager.com'
    p.font_src    :self, :https, :data
    p.connect_src :self, :https, 'https://www.googletagmanager.com', 'https://www.google-analytics.com', 'https://analytics.google.com', 'https://stats.g.doubleclick.net'

  end
end

# Keep these (do NOT hardcode a nonce string)
Rails.application.config.content_security_policy_nonce_generator  = ->(_req) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

