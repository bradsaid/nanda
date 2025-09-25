console.log("[app] application.js loaded");
import "@hotwired/turbo-rails";
import "controllers";
import "sort_table";
import "locations_map";   // when you're ready
Turbo.session.progressBarDelay = Infinity;