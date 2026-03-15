module ApplicationHelper
  def format_duration(seconds)
    return "—" if seconds.blank? || seconds <= 0
    mins = seconds.to_i / 60
    secs = seconds.to_i % 60
    mins > 0 ? "#{mins}m #{secs}s" : "#{secs}s"
  end

  def linkify_survivors(text, survivors)
    return text if text.blank? || survivors.blank?
    escaped = ERB::Util.html_escape(text)
    # Sort by name length descending to match longer names first (e.g. "Jeff Zausch" before "Jeff")
    survivors.sort_by { |s| -s.full_name.length }.each do |s|
      escaped = escaped.gsub(/\b#{Regexp.escape(s.full_name)}\b/i) do |match|
        "<a href=\"#{survivor_path(s)}\" class=\"link-primary fw-medium\">#{ERB::Util.html_escape(match)}</a>"
      end
    end
    simple_format(escaped.html_safe)
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

  def food_icon(food_source)
    food_icon_by_name(food_source.name, food_source.category)
  end

  def food_icon_by_name(name, category)
    n = name.to_s.downcase
    case n
    when /snake/                          then "🐍"
    when /lizard|iguana/                  then "🦎"
    when /caiman|crocodile|alligator/     then "🐊"
    when /turtle|tortoise/                then "🐢"
    when /frog|toad/                      then "🐸"
    when /crab/                           then "🦀"
    when /lobster|crayfish|crawfish/      then "🦞"
    when /shrimp|prawn/                   then "🦐"
    when /clam|mussel|oyster|shellfish/   then "🐚"
    when /snail|conch/                    then "🐌"
    when /fish|piranha|catfish|trout|bass|tilapia|perch|minnow/ then "🐟"
    when /eel/                            then "🐍"
    when /bird|chicken|duck|goose|pigeon|dove|parrot/ then "🐦"
    when /pig|boar|hog|peccary/           then "🐗"
    when /deer|elk|moose/                 then "🦌"
    when /goat/                           then "🐐"
    when /rabbit|hare/                    then "🐇"
    when /rat|mouse/                      then "🐀"
    when /monkey/                         then "🐒"
    when /scorpion/                       then "🦂"
    when /spider/                         then "🕷️"
    when /ant|termite/                    then "🐜"
    when /beetle|cricket|grasshopper/     then "🦗"
    when /worm|grub|larva|maggot/         then "🪱"
    when /shark/                          then "🦈"
    when /octopus|squid/                  then "🐙"
    when /jellyfish/                      then "🪼"
    when /urchin/                         then "🟣"
    when /coconut/                        then "🥥"
    when /banana/                         then "🍌"
    when /mango/                          then "🥭"
    when /papaya/                         then "🍈"
    when /pineapple/                      then "🍍"
    when /berry|berries/                  then "🫐"
    when /fruit/                          then "🍇"
    when /yam|potato|tuber|taro|cassava/  then "🍠"
    when /mushroom|fungus|fungi/          then "🍄"
    when /corn/                           then "🌽"
    when /rice/                           then "🍚"
    when /nut/                            then "🥜"
    when /bamboo/                         then "🎋"
    when /cactus/                         then "🌵"
    when /seaweed|kelp|algae/             then "🌿"
    when /herb|mint|basil|sage/           then "🌿"
    else
      category.to_s == "animal" ? "🍖" : "🌱"
    end
  end
end
