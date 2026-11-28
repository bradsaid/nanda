# <title> and meta description building blocks shared by the views.
#
#   content_for :title, site_title("Privacy Policy")             # "Privacy Policy — Naked & Afraid Fan Wiki"
#   content_for :title, paginated_title("Naked and Afraid Survivors", canonical_page_number)
#   content_for :meta_description, paginated_description("Browse ...", canonical_page_number)
#   content_for :meta_description, meta_excerpt(post.body_html)   # plain text, ~150 chars
module SeoHelper
  SITE_TITLE_NAME   = "Naked & Afraid Fan Wiki".freeze
  TITLE_SEPARATOR   = " — ".freeze
  # Longest <title> any public page may emit, page suffix included (search engines cut
  # around 60 characters). The ONE constant: change it here and every template follows.
  # Titles are built from candidates, richest first (see #site_title); the site-name suffix
  # is the first thing dropped, then the page's own qualifiers, and only as a last resort is
  # the text cut at a word boundary.
  MAX_TITLE_LENGTH  = 60
  DESCRIPTION_LIMIT = 160
  EXCERPT_LENGTH    = 150

  # The title for a page: the first of `core` and `fallbacks` (richest first) that fits in
  # MAX_TITLE_LENGTH together with the "— Page N" suffix, with the site name appended when
  # that still fits (never doubled: "Naked and Afraid Fan Wiki", "Naked & Afraid Fan Database"
  # already end in a site name, and the site name alone is left alone). If even the last
  # fallback is too long it is cut at a word boundary ("…"), so no page ever overflows.
  #
  #   site_title("Privacy Policy")                                # "Privacy Policy — Naked & Afraid Fan Wiki"
  #   site_title("Long qualified title", "Shorter title", page: 3)
  def site_title(core, *fallbacks, page: nil)
    title = fitted_title(core, *fallbacks, page: page, with_page: false)
    room  = MAX_TITLE_LENGTH - page_suffix(page).length
    unless title_names_site?(title) || (title + TITLE_SEPARATOR + SITE_TITLE_NAME).length > room
      title += TITLE_SEPARATOR + SITE_TITLE_NAME
    end
    paginated_title(title, page)
  end

  # Like #site_title but never adds the site name: the first candidate that fits (with the
  # "— Page N" suffix), else the last one cut at a word boundary.
  def fitted_title(*candidates, page: nil, with_page: true)
    candidates = candidates.flatten.map { |c| c.to_s.squish }.reject(&:blank?)
    return paginated_title(SITE_TITLE_NAME, (page if with_page)) if candidates.empty?
    room  = MAX_TITLE_LENGTH - page_suffix(page).length
    title = candidates.find { |c| c.length <= room } || truncate_at_word(candidates.last, room)
    with_page ? paginated_title(title, page) : title
  end

  # " — Page N" after the first page; page one keeps its title. A base title that would push
  # the result past MAX_TITLE_LENGTH is cut at a word boundary to make room for the suffix.
  def paginated_title(title, page)
    title = title.to_s
    return title unless page.to_i > 1
    suffix = page_suffix(page)
    title = truncate_at_word(title, MAX_TITLE_LENGTH - suffix.length) if (title + suffix).length > MAX_TITLE_LENGTH
    "#{title}#{suffix}"
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

  def page_suffix(page) = page.to_i > 1 ? "#{TITLE_SEPARATOR}Page #{page.to_i}" : ""

  # Does the title already end in the site's name? "&" and "and" count the same.
  def title_names_site?(title)
    normalized = title.downcase.tr("&", " ").gsub(/\band\b/, " ").squish
    normalized.end_with?("naked afraid fan wiki", "naked afraid fan database", "naked afraid fan forum")
  end
end
