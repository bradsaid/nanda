pin "application", to: "app.js", preload: true

pin "@hotwired/turbo-rails",       to: "turbo.min.js"
pin "@hotwired/stimulus",          to: "stimulus.min.js"
pin "@hotwired/stimulus-loading",  to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "sort_table",    to: "sort_table.js"
pin "leaflet",       to: "leaflet.js"
pin "locations_map", to: "locations_map.js"
pin "gtag",          to: "gtag.js"

#schema
pin "json_ld/helpers", to: "json_ld/helpers.js"
pin "json_ld/home_schema", to: "json_ld/home_schema.js"

pin "json_ld/episode_show", to: "json_ld/episode_show.js"
pin "json_ld/episodes_index", to: "json_ld/episodes_index.js"
pin "json_ld/episodes_by_country", to: "json_ld/episodes_by_country.js"

pin "json_ld/items_index", to: "json_ld/items_index.js"
pin "json_ld/item_show", to: "json_ld/item_show.js"
pin "json_ld/item_type", to: "json_ld/item_type.js"

pin "json_ld/locations_index", to: "json_ld/locations_index.js"

pin "json_ld/seasons_index", to: "json_ld/seasons_index.js"
pin "json_ld/season_show", to: "json_ld/season_show.js"

pin "json_ld/survivors_index", to: "json_ld/survivors_index.js"
pin "json_ld/survivor_show", to: "json_ld/survivor_show.js"

pin "json_ld/podcasts_books", to: "json_ld/podcasts_books.js"
pin "json_ld/about", to: "json_ld/about.js"
