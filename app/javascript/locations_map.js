// app/javascript/locations_map.js
import L from "leaflet";

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function buildMap(el) {
  if (el._leaflet_map) return el._leaflet_map; // reuse if exists

  const map = L.map(el, { scrollWheelZoom: true });
  el._leaflet_map = map;

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: "&copy; OpenStreetMap contributors",
  }).addTo(map);

  return map;
}

function destroyMap(el) {
  if (el && el._leaflet_map) {
    el._leaflet_map.remove();
    el._leaflet_map = null;
  }
}

function initLocationsMap() {
  const el = document.getElementById("locations-map");
  if (!el) return;

  const url = el.dataset.locationsUrl;
  if (!url || !/^\/locations(\.json|(\?|$))/.test(url)) return;

  const map = buildMap(el);

  fetch(url, { headers: { Accept: "application/json" } })
    .then((r) => {
      if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
      return r.json();
    })
    .then((rows) => {
      console.log(`[locations] fetched ${rows.length} rows from ${url}`);

      // Clear previous group if any
      if (el._leaflet_group) {
        try {
          map.removeLayer(el._leaflet_group);
        } catch {}
        el._leaflet_group = null;
      }

      const group = L.featureGroup();
      let added = 0;

      rows.forEach((loc) => {
        const lat = Number(loc.latitude);
        const lng = Number(loc.longitude);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
        if (Math.abs(lat) < 1e-6 && Math.abs(lng) < 1e-6) return;

        const marker = L.circleMarker([lat, lng], {
          radius: 6,
          weight: 2,
          opacity: 1,
          color: "#1f6feb",
          fillColor: "#79b8ff",
          fillOpacity: 0.8,
        });

        const name = escapeHtml(loc.name ?? "-");
        const country = escapeHtml(loc.country ?? "-");
        const region = loc.region ? " · " + escapeHtml(loc.region) : "";
        const count = Number(loc.episodes_count) || 0;

        const link = loc.episodes_url
          ? `<div class="mt-1">
               <a class="link-primary text-decoration-underline" href="${loc.episodes_url}">
                 View episodes at this location
               </a>
             </div>`
          : "";

        marker.bindPopup(
          `<div class="popup-box">
             <div><strong>${name}</strong></div>
             <div class="text-muted">${country}${region}</div>
             <div>Episodes: ${count}</div>
             ${link}
           </div>`
        );

        marker.addTo(group);
        added++;
      });

      console.log(`[locations] added ${added} markers`);
      if (added) {
        group.addTo(map);
        el._leaflet_group = group;
        map.fitBounds(group.getBounds().pad(0.10), { maxZoom: 5 }); // zoom in more
      } else {
        map.setView([20, 0], 3); // default world-ish view
      }
    })
    .catch((e) => {
      console.error("Failed to load locations:", e);
      map.setView([20, 0], 2);
    });
}

// Turbo lifecycle
document.addEventListener("turbo:load", initLocationsMap);
document.addEventListener("DOMContentLoaded", initLocationsMap);
document.addEventListener("turbo:before-cache", () => {
  const el = document.getElementById("locations-map");
  destroyMap(el);
});
