module ApplicationHelper
  def format_duration(seconds)
    return "—" if seconds.blank? || seconds <= 0
    mins = seconds.to_i / 60
    secs = seconds.to_i % 60
    mins > 0 ? "#{mins}m #{secs}s" : "#{secs}s"
  end

  def item_icon(item)
    name = item.is_a?(String) ? item : item&.name.to_s
    case name
    when /\A\?\z/                            then "❓"
    when /axe|tomahawk|hatchet|pulaski/      then "🪓"
    when /sword/                             then "⚔️"
    when /saw/                               then "🪚"
    when /knife|machete|kukri|blade/         then "🔪"
    when /pan/                               then "🍳"
    when /pot|pottery/                       then "🍲"
    when /blow\s*gun/                        then "🪈"
    when /bow drill/                         then "🔥"
    when /permanganate/                      then "🔥"
    when /magnif|glass.*lens/                then "🔍"
    when /fire|lighter|flint/                then "🔥"
    when /\bbow\b|arrow/                     then "🏹"
    when /spear|atlatl|dart/                 then "🗡️"
    when /sling/                             then "🎯"
    when /snare/                             then "🪤"
    when /hook/                              then "🪝"
    when /cast.*net/                         then "🕸️"
    when /snorkel|diving mask|scuba/         then "🤿"
    when /goggle/                            then "🥽"
    when /\bfins?\b/                         then "🤿"
    when /slack\s*line/                      then "🪢"
    when /fish|line(?!n)/                    then "🎣"
    when /rope/                              then "🪢"
    when /cord|string|paracord/              then "🪢"
    when /hammock/                           then "🛏️"
    when /tent/                              then "⛺"
    when /tarp/                              then "🛖"
    when /shelter/                           then "🛖"
    when /duct/                              then "🩹"
    when /mosquito/                          then "🦟"
    when /\bhide\b|pelt|skin|\bfurs?\b/      then "🦌"
    when /shovel/                            then "⛏️"
    when /boat/                              then "🛶"
    when /paddle/                            then "🛶"
    when /fabric|cloth/                      then "🧵"
    when /flash\s*light|torch/               then "🔦"
    when /bailer|bucket/                     then "🪣"
    when /lens/                              then "🔍"
    when /mask/                              then "🤿"
    else
      type = item.respond_to?(:item_type) ? (item.item_type rescue nil) : nil
      case type
      when "blade"              then "🔪"
      when "pot"                then "🍲"
      when "fire starting tool" then "🔥"
      when "hunting weapon"     then "🏹"
      when "fishing tool"       then "🎣"
      when "cordage"            then "🪢"
      when "comfort item"       then "🛖"
      when "digging tool"       then "⛏️"
      else "🔧"
      end
    end
  end
end
