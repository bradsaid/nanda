module LocationsHelper
  US_STATES = {
    "Alabama"    => "al", "Alaska"     => "ak", "Arizona"   => "az",
    "Arkansas"   => "ar", "California" => "ca", "Colorado"  => "co",
    "Connecticut" => "ct", "Delaware"  => "de", "Florida"   => "fl",
    "Georgia"    => "ga", "Hawaii"     => "hi", "Idaho"     => "id",
    "Illinois"   => "il", "Indiana"    => "in", "Iowa"      => "ia",
    "Kansas"     => "ks", "Kentucky"   => "ky", "Louisiana" => "la",
    "Maine"      => "me", "Maryland"   => "md", "Massachusetts" => "ma",
    "Michigan"   => "mi", "Minnesota"  => "mn", "Mississippi" => "ms",
    "Missouri"   => "mo", "Montana"    => "mt", "Nebraska"  => "ne",
    "Nevada"     => "nv", "New Hampshire" => "nh", "New Jersey" => "nj",
    "New Mexico" => "nm", "New York"   => "ny", "North Carolina" => "nc",
    "North Dakota" => "nd", "Ohio"     => "oh", "Oklahoma"  => "ok",
    "Oregon"     => "or", "Pennsylvania" => "pa", "Rhode Island" => "ri",
    "South Carolina" => "sc", "South Dakota" => "sd", "Tennessee" => "tn",
    "Texas"      => "tx", "Utah"       => "ut", "Vermont"   => "vt",
    "Virginia"   => "va", "Washington" => "wa", "West Virginia" => "wv",
    "Wisconsin"  => "wi", "Wyoming"    => "wy"
  }.freeze

  COUNTRIES = {
    "Argentina" => "ar", "Australia" => "au", "Bahamas" => "bs",
    "Belize" => "bz", "Bolivia" => "bo", "Botswana" => "bw",
    "Brazil" => "br", "Brasil" => "br", "Bulgaria" => "bg",
    "Cambodia" => "kh", "Canada" => "ca", "Colombia" => "co",
    "Costa Rica" => "cr", "Croatia" => "hr", "Dominica" => "dm",
    "Dominican Republic" => "do", "Ecuador" => "ec", "Fiji" => "fj",
    "Ghana" => "gh", "Guatemala" => "gt", "Guyana" => "gy",
    "Honduras" => "hn", "Iceland" => "is", "India" => "in",
    "Indonesia" => "id", "Jamaica" => "jm", "Kenya" => "ke",
    "Madagascar" => "mg", "Malaysia" => "my", "Maldives" => "mv",
    "Mexico" => "mx", "Mongolia" => "mn", "Montserrat" => "ms",
    "Mozambique" => "mz", "Namibia" => "na", "Nepal" => "np",
    "Nicaragua" => "ni", "Nigeria" => "ng", "Norway" => "no",
    "Panama" => "pa", "Papua New Guinea" => "pg", "Peru" => "pe",
    "Philippines" => "ph", "South Africa" => "za", "Tanzania" => "tz",
    "Thailand" => "th", "Tobago" => "tt", "Trinidad" => "tt",
    "Trinidad and Tobago" => "tt", "United States" => "us", "USA" => "us",
    "Vietnam" => "vn", "Zambia" => "zm", "Zimbabwe" => "zw"
  }.freeze

  # Returns the flag image URL for a location's country value. Checks US states
  # first (because the show often stores the state directly in the country
  # column) so "Mississippi" resolves to the US state flag rather than
  # being confused with Montserrat (which shares the ISO code "ms").
  def country_flag_url(country, size: 40)
    return nil if country.blank?
    name = country.to_s.strip
    if (state_code = US_STATES[name])
      "https://flagcdn.com/w#{size}/us-#{state_code}.png"
    elsif (cc = COUNTRIES[name])
      "https://flagcdn.com/w#{size}/#{cc}.png"
    end
  end

  def country_flag_alt(country)
    name = country.to_s.strip
    US_STATES.key?(name) ? "#{name} flag" : "#{name} flag"
  end

  # Returns an outline-shape image URL for a country or US state.
  # Countries: mapsicon silhouette via jsdelivr proxy.
  # US states: Wikipedia's blank "location map" file for the state — a clean
  # outline of just the state with no surrounding US context. Suitable as a
  # standalone shape and as a CSS mask-image source.
  def country_outline_url(country, width: 120)
    return nil if country.blank?
    name = country.to_s.strip
    if US_STATES.key?(name)
      filename = "USA_#{name.tr(' ', '_')}_location_map.svg"
      "https://commons.wikimedia.org/wiki/Special:FilePath/#{filename}?width=#{width}"
    elsif (cc = COUNTRIES[name])
      "https://cdn.jsdelivr.net/gh/djaiss/mapsicon@master/all/#{cc}/vector.svg"
    end
  end
end
