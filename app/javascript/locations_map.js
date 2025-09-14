import L from "leaflet";

function initMap() {
  const el = document.getElementById("map");
  if (!el || el.dataset.inited) return;
  el.dataset.inited = "1";

  const map = L.map("map", { scrollWheelZoom: true });
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 18,
    attribution: "&copy; OpenStreetMap"
  }).addTo(map);

  // Ensure proper sizing even if fonts/layout shift after init
  const invalidate = () => map.invalidateSize();
  window.addEventListener("load", invalidate, { once: true });
  setTimeout(invalidate, 0);
  setTimeout(invalidate, 300);

  fetch("/locations.json")
    .then(r => r.json())
    .then(data => {
      if (!Array.isArray(data) || data.length === 0) { map.setView([20, 0], 2); invalidate(); return; }
      const bounds = [];
      data.forEach(loc => {
        if (typeof loc.latitude !== "number" || typeof loc.longitude !== "number") return;
        L.marker([loc.latitude, loc.longitude]).addTo(map);
        bounds.push([loc.latitude, loc.longitude]);
      });
      bounds.length ? map.fitBounds(bounds, { padding: [30, 30] }) : map.setView([20, 0], 2);
      invalidate();
    })
    .catch(() => { map.setView([20, 0], 2); invalidate(); });
}

document.addEventListener("turbo:load", initMap);
document.addEventListener("DOMContentLoaded", initMap);
