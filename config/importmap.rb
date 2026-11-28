# Modules are pinned here but only *preloaded* (<link rel="modulepreload">) when
# they are needed on every page. Everything marked `preload: false` is still
# resolvable through the import map; it is just not fetched until a page that
# needs it imports it (see javascript_import_module_tag in the layout/views).
pin "application", to: "app.js", preload: true

pin "@hotwired/turbo-rails",       to: "turbo.min.js"
pin "@hotwired/stimulus",          to: "stimulus.min.js"
pin "@hotwired/stimulus-loading",  to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "sort_table",    to: "sort_table.js"
pin "leaflet",       to: "leaflet.js", preload: false           # ~147 KB; map pages only
pin "locations_map", to: "locations_map.js", preload: false  # imported by the layout on map pages
pin "page_timer",    to: "page_timer.js"
pin "episode_form",  to: "episode_form.js", preload: false      # admin episode form only
pin "survivors_search", to: "survivors_search.js"
pin "items_search", to: "items_search.js"
pin "forum_mentions", to: "forum_mentions.js", preload: false  # forum composers only
pin "forum_clickable", to: "forum_clickable.js"
pin "forum_promo", to: "forum_promo.js"
pin "locations_search", to: "locations_search.js"
pin "consent",       to: "consent.js"
pin "admin_views_chart", to: "admin_views_chart.js", preload: false  # admin dashboard only

#schema
pin "json_ld/helpers", to: "json_ld/helpers.js", preload: false
pin "json_ld/home_schema", to: "json_ld/home_schema.js", preload: false

pin "json_ld/episode_show", to: "json_ld/episode_show.js", preload: false
pin "json_ld/episodes_index", to: "json_ld/episodes_index.js", preload: false
pin "json_ld/episodes_by_country", to: "json_ld/episodes_by_country.js", preload: false

pin "json_ld/items_index", to: "json_ld/items_index.js", preload: false
pin "json_ld/item_show", to: "json_ld/item_show.js", preload: false
pin "json_ld/item_type", to: "json_ld/item_type.js", preload: false

pin "json_ld/locations_index", to: "json_ld/locations_index.js", preload: false

pin "json_ld/seasons_index", to: "json_ld/seasons_index.js", preload: false
pin "json_ld/season_show", to: "json_ld/season_show.js", preload: false

pin "json_ld/survivors_index", to: "json_ld/survivors_index.js", preload: false
pin "json_ld/survivor_show", to: "json_ld/survivor_show.js", preload: false

pin "json_ld/podcasts_books", to: "json_ld/podcasts_books.js", preload: false
pin "json_ld/about", to: "json_ld/about.js", preload: false
