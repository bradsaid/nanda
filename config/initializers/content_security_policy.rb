# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |p|
    p.default_src :self
    p.script_src  :self, :https
    p.style_src   :self, :https, :unsafe_inline
    p.img_src     :self, :https, :data    # <-- this line allows remote map tiles
    p.font_src    :self, :https, :data
    p.connect_src :self, :https
  end
end

# Keep these (do NOT hardcode a nonce string)
Rails.application.config.content_security_policy_nonce_generator  = ->(_req) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w(script-src)