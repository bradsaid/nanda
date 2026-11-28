require "uri"

module Forum
  # Outbound links inside user-generated forum HTML must not pass ranking and must not
  # hand the destination a handle on our page: every <a href> that leads off this site
  # gets rel="ugc nofollow noopener noreferrer".
  #
  #   * "ugc" / "nofollow": Google's markers for links we did not editorially vouch for.
  #   * "noopener" / "noreferrer": the destination cannot reach window.opener, and gets no
  #     Referer. (Posts cannot set a target at all, see Forum::Post::ALLOWED_ATTRIBUTES, so
  #     links open in the same tab exactly as before; the rel is belt and braces.)
  #
  # The rel is set here unconditionally (an author-supplied rel is replaced, not merged), so
  # it holds even if the sanitiser's allowlist were ever widened. Links to this site itself
  # (relative paths, #anchors, the canonical host) are left alone: nofollowing our own pages
  # would only cost internal links their weight.
  #
  # Used when a post is saved (Forum::Post#render_html, so stored body_html carries it) and
  # again when a post is rendered (ForumHelper#forum_post_html), which also covers posts
  # saved before this existed. Applying it twice is harmless.
  module UgcLinks
    REL = "ugc nofollow noopener noreferrer".freeze
    OWN_HOSTS = %w[nakedandafraidfan.com www.nakedandafraidfan.com].freeze

    module_function

    def apply(html)
      html = html.to_s
      return html unless html.match?(/<a[\s>]/i)

      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css("a[href]").each do |link|
        next unless external?(link["href"])
        link["rel"] = REL
        link.remove_attribute("target") # posts cannot set one; never let one through
      end
      fragment.to_html
    end

    # Anything that is not a relative path, a #fragment or one of our own hosts. An
    # unparseable href is treated as external (the safe side).
    def external?(href)
      value = href.to_s.strip.gsub(/[\u0000-\u001F\u007F]/, "")
      return false if value.empty? || value.start_with?("#")
      return false if value.start_with?("/") && !value.start_with?("//")

      uri = URI.parse(value)
      return true if uri.host.blank? && uri.scheme.present? # mailto:, tel:, ...
      return false if uri.host.blank? # relative: "page", "?q=1"

      !OWN_HOSTS.include?(uri.host.downcase)
    rescue URI::InvalidURIError
      true
    end
  end
end
