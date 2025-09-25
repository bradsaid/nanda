pin "application", to: "app.js", preload: true

pin "@hotwired/turbo-rails",       to: "turbo.min.js"
pin "@hotwired/stimulus",          to: "stimulus.min.js"
pin "@hotwired/stimulus-loading",  to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "sort_table",    to: "sort_table.js"
pin "leaflet",       to: "leaflet.js"
pin "locations_map", to: "locations_map.js"
pin "locations_test", to: "locations_test.js"