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

  # Try IG (disabled by default), then FB Page avatar. Return URL or nil.
  def social_avatar_url(survivor, size: 256)
    # If you want to *try* IG via unavatar knowing it 404s often, uncomment:
    if (h = ig_handle(survivor.instagram)).present?
       return "https://unavatar.io/instagram/#{ERB::Util.url_encode(h)}?size=#{size}"
    end

    if (h = fb_handle(survivor.facebook)).present?
      # Graph API picture (works for public *Pages*; users may not)
      return "https://graph.facebook.com/#{ERB::Util.url_encode(h)}/picture?type=large&width=#{size}&height=#{size}"
    end

    nil
  end


end
