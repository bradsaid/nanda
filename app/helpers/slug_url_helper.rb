# The one place that turns names and ids into slug URLs, so no call site has to know:
#
#   by_country_episodes_path("South Africa")   => /episodes/by_country/south-africa
#   food_source_path(name: "angel fish")       => /food_sources/angel-fish
#   shelter_path("Lean-to")                    => /shelters/lean-to
#   type_items_path("fire starting tool")      => /items/types/fire-starting-tool
#   item_path(17) / episode_path(139)          => the slug URL (a bare id is looked up)
#   item_path(item) / episode_path(episode)    => the slug URL (the record's #to_param)
#
# Included into every view and helper (Rails includes all helpers), after the route helpers,
# so these wrap them. Controllers and models, which do not get helper modules, call
# NameSlugs.slug / RecordSlugs.param (or pass a record) directly.
module SlugUrlHelper
  NAME_ROUTES = {
    by_country_episodes: [:country,    :country],
    food_source:         [:name,       :food_source],
    shelter:             [:shelter_type, :shelter],
    type_items:          [:item_type,  :item_type]
  }.freeze

  RECORD_ROUTES = { episode: "Episode", item: "Item" }.freeze

  NAME_ROUTES.each do |route, (param, kind)|
    %w[path url].each do |suffix|
      define_method("#{route}_#{suffix}") do |*args, **opts|
        if args.first.is_a?(String)
          args[0] = NameSlugs.slug(kind, args.first)
        elsif opts[param].is_a?(String)
          opts[param] = NameSlugs.slug(kind, opts[param])
        end
        super(*args, **opts)
      end
    end
  end

  RECORD_ROUTES.each do |route, model|
    %w[path url].each do |suffix|
      define_method("#{route}_#{suffix}") do |*args, **opts|
        if numeric_id?(args.first)
          args[0] = RecordSlugs.param(model.constantize, args.first)
        elsif numeric_id?(opts[:id])
          opts[:id] = RecordSlugs.param(model.constantize, opts[:id])
        end
        super(*args, **opts)
      end
    end
  end

  # Rewrites the old-style internal links inside stored HTML (survivor bios hold hand-written
  # <a href="/episodes/138"> and <a href="/episodes/by_country/South%20Africa">) to their slug
  # URLs. Links it cannot match are left as written (they still 301 or 404 as they would).
  def slug_internal_links(html)
    html.gsub(%r{href="/(episodes|items)/(\d+)(?=["?#])}) do
      type, id = $1, $2
      model = type == "episodes" ? Episode : Item
      %(href="/#{type}/#{RecordSlugs.param(model, id)})
    end.gsub(%r{href="/episodes/by_country/([^"?#/]+)(?=["?#])}) do
      raw   = $1
      match = NameSlugs.resolve(:country, CGI.unescape(raw))
      match ? %(href="/episodes/by_country/#{match.slug}) : %(href="/episodes/by_country/#{raw})
    end
  end

  # A catalog "Source" link that points at one of our own pages by id
  # (https://www.nakedandafraidfan.com/items/17) goes to the slug URL; other URLs pass through.
  def slug_site_url(url)
    url.to_s.sub(%r{\A(https?://(?:www\.)?nakedandafraidfan\.com)/(episodes|items)/(\d+)(?=[/?#]|\z)}) do
      host, type, id = $1, $2, $3
      "#{host}/#{type}/#{RecordSlugs.param(type == 'episodes' ? Episode : Item, id)}"
    end
  end

  private

  def numeric_id?(value)
    value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A\d+\z/))
  end
end
