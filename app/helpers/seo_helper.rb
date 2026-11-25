# <title> and meta description building blocks shared by the views.
#
#   content_for :title, site_title("Privacy Policy")             # "Privacy Policy — Naked & Afraid Fan Wiki"
#   content_for :title, paginated_title("Naked and Afraid Survivors", canonical_page_number)
#   content_for :meta_description, paginated_description("Browse ...", canonical_page_number)
#   content_for :meta_description, meta_excerpt(post.body_html)   # plain text, ~150 chars
module SeoHelper
  SITE_TITLE_NAME   = "Naked & Afraid Fan Wiki".freeze
  TITLE_SEPARATOR   = " — ".freeze
  # Longest <title> we are happy to emit when adding the site name; search engines
  # truncate around 60 to 65 characters, so the suffix is dropped rather than overflow.
  MAX_TITLE_LENGTH  = 65
  DESCRIPTION_LIMIT = 160
  EXCERPT_LENGTH    = 150

  # `core` with the site name appended, unless it already ends with a site name (the
  # suffix is never doubled: "Naked and Afraid Fan Wiki", "Naked & Afraid Fan Database"),
  # is the site name, or would push the title past MAX_TITLE_LENGTH.
  def site_title(core, page: nil)
    core = core.to_s.squish
    return paginated_title(SITE_TITLE_NAME, page) if core.blank?
    title = core
    unless title_names_site?(title) || (title + TITLE_SEPARATOR + SITE_TITLE_NAME).length > MAX_TITLE_LENGTH
      title += TITLE_SEPARATOR + SITE_TITLE_NAME
    end
    paginated_title(title, page)
  end

  # " — Page N" after the first page; page one keeps its title.
  def paginated_title(title, page)
    page.to_i > 1 ? "#{title}#{TITLE_SEPARATOR}Page #{page.to_i}" : title.to_s
  end

  # "(page N)" after the first page, trimming the base text so the result still fits.
  def paginated_description(description, page)
    return description.to_s unless page.to_i > 1
    suffix = " (page #{page.to_i})"
    "#{truncate_at_word(description.to_s, DESCRIPTION_LIMIT - suffix.length)}#{suffix}"
  end

  # Plain-text excerpt of user or editor content: tags and entities removed, whitespace
  # squished, email addresses dropped, cut at a word boundary with an ellipsis.
  def meta_excerpt(text, limit: EXCERPT_LENGTH)
    plain = ActionView::Base.full_sanitizer.sanitize(text.to_s)
    plain = CGI.unescapeHTML(plain.to_s)
    plain = plain.gsub(/[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+/, "").squish
    truncate_at_word(plain, limit)
  end

  # `text` cut to at most `limit` characters at a word boundary, ending in "…" when cut.
  def truncate_at_word(text, limit)
    text = text.to_s.squish
    return text if text.length <= limit
    cut = text[0, limit - 1]
    mid_word = text[limit - 1] != " "
    cut = cut.sub(/\s+\S*\z/, "") if mid_word && cut.include?(" ")
    cut = cut.sub(/[\s,;:\-–—]+\z/, "")
    "#{cut}…"
  end

  private

  # Does the title already end in the site's name? "&" and "and" count the same.
  def title_names_site?(title)
    normalized = title.downcase.tr("&", " ").gsub(/\band\b/, " ").squish
    normalized.end_with?("naked afraid fan wiki", "naked afraid fan database", "naked afraid fan forum")
  end
end
