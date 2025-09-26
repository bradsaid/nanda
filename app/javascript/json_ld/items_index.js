import { injectJsonLd } from "./inject";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("items-index-jsonld-data");
  if (!el) return;

  const payload = JSON.parse(el.textContent);
  injectJsonLd({
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "name": "Naked and Afraid Items",
    "description": "Database of survival items used in Naked and Afraid, including brought, given, and rare items by type and country.",
    "url": window.location.href,
    "about": payload.items
  });
});
