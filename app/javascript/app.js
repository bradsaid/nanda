//console.log("[app] application.js loaded");
import "@hotwired/turbo-rails";
import "controllers";
import "sort_table";
import "locations_map";   // when you're ready
import "gtag";
import "page_timer";
Turbo.session.progressBarDelay = Infinity;
