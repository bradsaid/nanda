module SurvivorsHelper
  # "appeared in 78 episodes across 12 challenges" -- the wording shared by the survivor
  # page's meta/og descriptions and its Person JSON-LD, fed the numbers the page shows
  # (Episodes = number of appearances, Challenges = continuous seasons count once).
  def survivor_appearance_summary(episodes, challenges)
    episodes   = episodes.to_i
    challenges = challenges.to_i
    return "has no episodes on record yet" if episodes <= 0
    summary = "appeared in #{pluralize(episodes, 'episode')}"
    summary += " across #{pluralize(challenges, 'challenge')}" if challenges.positive?
    summary
  end

  META_DESCRIPTION_LIMIT = 160

  # The survivor page's <meta name="description">. Same text as before: the bio's first 160
  # characters, or a generic profile line when there is no bio. When the survivor has search
  # aliases they are woven in ONLY if the whole sentence still fits in 160 characters;
  # otherwise the description is exactly what it was.
  def survivor_meta_description(survivor, bio_plain)
    name  = survivor.full_name.to_s
    names = survivor.display_aliases
    if bio_plain.present?
      base = bio_plain.first(META_DESCRIPTION_LIMIT)
      return base if names.empty?
      woven = "#{bio_plain} (Also searched as: #{names.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')}.)"
      woven.length <= META_DESCRIPTION_LIMIT ? woven : base
    else
      generic = "Profile for #{name}: episodes, challenges, items brought/given, locations, and results."
      return generic if names.empty?
      woven = "Profile for #{name} (also searched as #{names.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')}): episodes, challenges, items brought/given, locations, and results."
      woven.length <= META_DESCRIPTION_LIMIT ? woven : generic
    end
  end

  # Rows for the survivor page's "Quick facts" card: [{ label:, value: }] with value a
  # string or safe HTML. Born/hometown/nationality appear ONLY when filled in; the rest is
  # computed from the appearances the page already loaded. Empty when there is nothing to show.
  def survivor_quick_facts(survivor, appearances:, episodes_count:, challenges_count:, country_names:)
    rows = []
    if survivor.birth_year
      age = survivor.approximate_age
      rows << { label: "Born", value: "#{survivor.birth_year} (~#{age} #{'year'.pluralize(age)} ago)" }
    end
    rows << { label: "Hometown",    value: survivor.hometown }    if survivor.hometown.present?
    rows << { label: "Nationality", value: survivor.nationality } if survivor.nationality.present?

    dated = Array(appearances).select { |a| a.episode&.air_date }
    if dated.any?
      first = dated.min_by { |a| [a.episode.air_date, a.episode_id] }.episode
      last  = dated.max_by { |a| [a.episode.air_date, a.episode_id] }.episode
      rows << { label: "First appearance", value: survivor_fact_episode_link(first) }
      rows << { label: "Latest appearance", value: survivor_fact_episode_link(last) } if last.id != first.id
    end
    if episodes_count.to_i.positive?
      rows << { label: "Episodes",   value: episodes_count.to_i.to_s }
      rows << { label: "Challenges", value: challenges_count.to_i.to_s } if challenges_count.to_i.positive?
    end
    names = Array(country_names).compact_blank
    if names.any?
      rows << { label: names.size == 1 ? "Country" : "Countries",
                value: safe_join(names.map { |c| link_to(c, by_country_episodes_path(country: c)) }, ", ") }
    end
    rows
  end

  # Data-driven Q&As for the optional quick facts: one per fact that is filled in, none
  # otherwise. Same {q:, a:} shape as the rest of survivor_faq_qas.
  def survivor_fact_qas(survivor)
    name = survivor.full_name.to_s
    qas  = []
    if survivor.birth_year
      age = survivor.approximate_age
      qas << { q: "How old is #{name}?",
               a: "#{name} was born in #{survivor.birth_year}, about #{age} #{'year'.pluralize(age)} ago (the age is worked out from the birth year)." }
    end
    if survivor.hometown.present?
      qas << { q: "Where is #{name} from?", a: "#{name}'s listed hometown is #{survivor.hometown}." }
    end
    if survivor.nationality.present?
      qas << { q: "What nationality is #{name}?", a: "#{name}'s listed nationality is #{survivor.nationality}." }
    end
    qas
  end

  def flip_dir(dir) = (dir == "desc" ? "asc" : "desc")

  def sort_arrow(active, dir)
    return "" unless active
    dir == "desc" ? "▼" : "▲"
  end

  def ig_handle(v)
    v.to_s.strip.sub(/\A@/, "")
     .sub(%r{\Ahttps?://(www\.)?instagram\.com/}i, "")
     .sub(%r{/.*$}, "")
  end

  def fb_handle(v)
    v.to_s.strip.sub(/\A@/, "")
     .sub(%r{\Ahttps?://(www\.)?facebook\.com/}i, "")
     .sub(%r{/.*$}, "")
  end

  def yt_handle(v)
    raw = v.to_s.strip
    raw = raw.sub(/\A@/, "")
             .sub(%r{\Ahttps?://(www\.)?youtube\.com/(?:@|c/|channel/|user/)?}i, "")
             .sub(%r{/.*$}, "")
    raw.presence
  end

  def cameo_handle(v)
    clean_handle(v, %r{\Ahttps?://(www\.)?cameo\.com/}i)
  end

  # Renders an inline list of "[avatar][name]" link chips for survivors —
  # used on the episodes index / season cards / by_country table where the
  # survivor names previously rendered as comma-separated plain links.
  # Eager-load survivors with their avatars in the controller to avoid N+1.
  def survivor_chips(survivors, size: 22)
    survivors = Array(survivors)
    return content_tag(:span, "—", class: "text-muted") if survivors.empty?
    chips = survivors.map do |s|
      avatar = image_tag(avatar_src(s, name: s.full_name, variant: :chip),
                         alt: s.full_name,
                         width: size, height: size,
                         loading: "lazy",
                         class: "rounded-circle border me-1 align-middle flex-shrink-0",
                         style: "object-fit: cover;")
      link_to(safe_join([avatar, content_tag(:span, s.full_name, class: "align-middle")]),
              survivor_path(s),
              class: "text-decoration-none link-primary me-2 d-inline-block text-nowrap")
    end
    safe_join(chips)
  end

  # Displayed size (CSS px) of each avatar variant, for explicit width/height attributes so
  # the browser reserves the box before the image arrives (no layout shift). The variants
  # themselves are 2x these (see Survivor).
  AVATAR_DISPLAY_SIZES = {
    thumb:    [ 130, 170 ],  # .avatar-portrait (100x130 on phones; same aspect ratio)
    portrait: [ 130, 170 ],
    profile:  [ 160, 160 ],  # .avatar-lg (120x120 on phones)
    chip:     [ 40, 40 ]
  }.freeze

  # Returns a URL for the survivor's avatar at the requested variant size.
  # Variants defined on Survivor: :chip (80x80), :thumb (260x340), :portrait (520x680),
  # :profile (320x320), all WebP.
  #
  # The URL is Active Storage's PROXY route (/rails/active_storage/representations/proxy/...),
  # not the default redirect route. The redirect route answers 302 -> a short-lived signed S3
  # URL, so browsers and CDNs can never cache the image and every view pays an extra round
  # trip. The proxy URL is stable (signed blob id with no expiry: expires_in: nil) and the
  # response is `Cache-Control: public, max-age=<100 years>, immutable` (see
  # config/initializers/active_storage_cache_control.rb). Trade-off: the dyno streams the
  # bytes from S3 on a cache miss; put a CDN in front of /rails/active_storage/.
  #
  # Degrades safely: if the variant cannot be built (unknown name, blob not variable) it
  # falls back to the proxied original, then to an initials SVG if nothing is attached.
  def avatar_src(record, name: nil, variant: :thumb)
    if record&.avatar&.attached?
      begin
        return rails_storage_proxy_path(record.avatar.variant(variant), only_path: true, expires_in: nil)
      rescue StandardError
        begin
          return rails_storage_proxy_path(record.avatar, only_path: true, expires_in: nil)
        rescue StandardError
          nil
        end
      end
    end

    initials = (name.presence || "??").split.map { |w| w[0] }.join.first(2).upcase
    svg = <<~SVG
      <svg xmlns='http://www.w3.org/2000/svg' width='256' height='256'>
        <rect width='100%' height='100%' fill='#eee'/>
        <text x='50%' y='50%' dominant-baseline='middle' text-anchor='middle'
              font-family='system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial'
              font-size='96' fill='#777'>#{initials}</text>
      </svg>
    SVG
    "data:image/svg+xml;utf8,#{ERB::Util.url_encode(svg)}"
  end

  # <img> for a survivor avatar: stable cacheable proxy URL, WebP variant, explicit width and
  # height matching the displayed size, async decoding. Lazy by default; pass
  # loading: "eager" (and fetchpriority: "high") only for an image that is above the fold.
  def survivor_avatar_tag(survivor, name: nil, variant: :thumb, loading: "lazy", fetchpriority: nil, **options)
    width, height = AVATAR_DISPLAY_SIZES.fetch(variant, AVATAR_DISPLAY_SIZES[:thumb])
    name ||= survivor.full_name
    attrs = { alt: name, width: width, height: height, loading: loading, decoding: "async" }
    attrs[:fetchpriority] = fetchpriority if fetchpriority
    image_tag(avatar_src(survivor, name: name, variant: variant), **attrs, **options)
  end

  private

  def survivor_fact_episode_link(episode)
    label = episode.title.presence || "Episode #{episode.number_in_season}"
    safe_join([link_to(label, episode_path(episode)), " (#{episode.air_date.strftime('%b %-d, %Y')})"])
  end

  def clean_handle(value, domain_pattern)
    value.to_s.strip
         .sub(/\A@/, "")
         .sub(domain_pattern, "")
         .sub(%r{/.*$}, "")
         .presence
  end


end
