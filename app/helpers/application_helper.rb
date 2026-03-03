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
    when /axe|tomahawk|hatchet|pulaski/ then "🪓"
    when /sword/                        then "⚔️"
    when /saw/                          then "🪚"
    when /knife|machete|kukri|blade/    then "🔪"
    when /pan/                          then "🍳"
    when /pot|pottery/                  then "🍲"
    when /bow drill/                    then "🔥"
    when /fire|lighter|flint|lens/      then "🔥"
    when /\bbow\b|arrow/                then "🏹"
    when /spear|atlatl|dart/            then "🗡️"
    when /sling/                        then "🪃"
    when /snare/                        then "🪤"
    when /hook/                         then "🪝"
    when /fish|cast|line|mask|fins/     then "🎣"
    when /cord|rope|string|paracord/    then "🪢"
    when /hammock|tent/                 then "⛺"
    when /tarp/                         then "🛖"
    when /duct/                         then "🩹"
    when /mosquito/                     then "🦟"
    when /shovel/                       then "⛏️"
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
