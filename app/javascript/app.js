// Only code needed on every page lives here. Page-specific modules are imported
// by the pages that use them (javascript_import_module_tag):
//   locations_map (+ leaflet)  -> layout, on map pages (locations, episodes by country/location)
//   episode_form               -> admin/episodes/_form
//   forum_mentions             -> forum composers (topic reply, new topic, edit post)
//   admin_views_chart          -> admin dashboard
// gtag.js is loaded once, as a classic <script>, by the layout (importing it here
// as well ran the Google Tag Manager/gtag bootstrap twice per page).
import "@hotwired/turbo-rails";
import "controllers";
import "sort_table";
import "page_timer";
import "survivors_search";
import "items_search";
import "forum_clickable";
import "forum_promo";
import "locations_search";
import "consent";
Turbo.session.progressBarDelay = Infinity;
