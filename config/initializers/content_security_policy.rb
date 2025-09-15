Rails.application.config.content_security_policy do |p|
  p.default_src :self
  p.script_src  :self, :https, "https://ga.jspm.io"
  p.style_src   :self, :https            # no inline <style> tags
  p.style_src_attr :unsafe_inline        # ✅ allow style="" attributes (Leaflet needs this)
  p.img_src     :self, :https, :data
  p.font_src    :self, :https, :data
  p.object_src  :none
  p.connect_src :self
end

Rails.application.config.content_security_policy_nonce_generator  = ->(_req) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w(script-src style-src)
