import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#locations-index-jsonld-data");
  if (!d) return;
  const countries = Object.entries(d.countries || {}).map(([name, total]) => ({
    "@type":"Place","name": name,"description": `${total} episodes filmed`
  }));
  injectJsonLd({
    "@context":"https://schema.org","@type":"CollectionPage",
    "name": "Naked and Afraid Locations",
    "description": "Map and country breakdown of filming locations across all episodes.",
    "url": window.location.href,
    "hasPart": countries
  });
}

document.addEventListener("DOMContentLoaded", run);
