module SeasonsHelper
  SERVICE_LABELS = {
    discovery_plus: "Discovery+",
    max:            "Max",
    hulu:           "Hulu",
    disney_plus:    "Disney+",
    netflix:        "Netflix",
    prime_video:    "Prime Video"
  }.freeze

  def streaming_label(key)
    SERVICE_LABELS[key.to_sym] || key.to_s.titleize
  end
end