# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src :self, :https
#     policy.font_src    :self, :https, :data
#     policy.img_src     :self, :https, :data
#     policy.object_src  :none
#     policy.script_src  :self, :https
#     policy.style_src   :self, :https
#     # Specify URI for violation reports
#     # policy.report_uri "/csp-violation-report-endpoint"
#   end
#
#   # Generate session nonces for permitted importmap, inline scripts, and inline styles.
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w(script-src style-src)
#
#   # Report violations without enforcing the policy.
#   # config.content_security_policy_report_only = true
# end

Rails.application.config.content_security_policy do |policy|
  policy.script_src :self, :https, "https://code.jquery.com", "https://cdn.datatables.net"
  policy.style_src  :self, :https, "https://cdn.datatables.net"
end

# Make Rails emit nonces so inline tags from helpers (e.g. importmap) are allowed
Rails.application.config.content_security_policy_nonce_generator = ->(_req) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w(script-src style-src)

Rails.application.configure do
  config.content_security_policy do |p|
    cdn = "https://unpkg.com"
    p.default_src :self
    p.script_src  :self
    p.style_src   :self, :https, cdn
    p.style_src_attr :unsafe_inline   # ← allow only inline style *attributes*
    p.img_src     :self, :https, :data, cdn
    p.connect_src :self
    p.font_src    :self, :https, :data
  end
end




