module SurvivorsHelper
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

  def avatar_src(record, name: nil)
    return rails_blob_path(record.avatar, only_path: true) if record&.avatar&.attached?

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




end
