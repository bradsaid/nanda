// app/javascript/locations_map.js
//console.log("[map] locations_map loaded");
import "leaflet";                // UMD build -> window.L

const pick = n => document.querySelector(`meta[name="${n}"]`)?.content;
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl:       pick("leaflet-icon"),
  iconRetinaUrl: pick("leaflet-icon-2x"),
  shadowUrl:     pick("leaflet-shadow"),
});

document.addEventListener("turbo:load", () => {
  const el = document.getElementById("locations-map");
  if (!el) return console.warn("[map] #locations-map not found");

  const url = el.dataset.locationsUrl;
  if (!url) return console.warn("[map] missing data-locations-url");

  const L = window.L;
  if (!L) return console.error("[map] Leaflet missing");

  const map = L.map(el, {
    scrollWheelZoom: true,
    worldCopyJump: false,
    maxBounds: [[-85, -180], [85, 180]],
    maxBoundsViscosity: 1.0,
    minZoom: 2,
  });

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap contributors",
    maxZoom: 18,
    noWrap: true,
    bounds: [[-85, -180], [85, 180]],
  }).addTo(map);

  fetch(url, { headers: { Accept: "application/json" } })
    .then(r => r.json())
    .then(points => {
      console.log("[map] points", points);
      if (!points.length) return map.setView([20, 0], 2);

      const markers = points.map(p => {
        const m = L.marker([p.lat, p.lng]).addTo(map);
        const title = p.name || p.address || "Location";
        // A country-only location has name === address; don't print it twice.
        const sameAsTitle = (p.address || "").trim().toLowerCase() === title.trim().toLowerCase();
        const addressLine = p.address && !sameAsTitle ? `${p.address}<br>` : "";
        const n = p.challenges_count ?? p.episodes_count;
        const e = p.episodes_count ?? 0;
        const ep = `${n} challenge${n === 1 ? "" : "s"}<br>${e} episode${e === 1 ? "" : "s"}`;
        const link = p.episodes_url ? `<div class="mt-1"><a href="${p.episodes_url}">View challenges</a></div>` : "";
        m.bindPopup(`<div><strong>${title}</strong><br>${addressLine}${ep}${link}</div>`);
        return m;
      });

      const group = L.featureGroup(markers);
      map.fitBounds(group.getBounds().pad(0.15));
    })
    .catch(e => {
      console.error("[map] fetch error", e);
      map.setView([20, 0], 2);
    });
});
