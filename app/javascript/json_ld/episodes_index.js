import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#episodes-index-jsonld-data");
  if (!d) return;

  const schema = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "name": d.name || "Naked and Afraid Episodes",
    "numberOfItems": d.count,
    "description": d.description || "Episode list with seasons, survivors, and locations.",
    "itemListElement": (d.episodes || []).map((ep, i) => ({
      "@type": "ListItem",
      "position": i + 1,
      "url": ep.url,
      "name": ep.name,
      "additionalProperty": [
        ep.series ? { "@type": "PropertyValue", "name": "Series", "value": ep.series } : undefined,
        ep.season ? { "@type": "PropertyValue", "name": "Season", "value": ep.season } : undefined,
        ep.number ? { "@type": "PropertyValue", "name": "Episode", "value": ep.number } : undefined,
        ep.air_date ? { "@type": "PropertyValue", "name": "Air Date", "value": ep.air_date } : undefined,
        ep.location ? { "@type": "PropertyValue", "name": "Location", "value": ep.location } : undefined
      ].filter(Boolean)
    }))
  };

  injectJsonLd(schema);
}

document.addEventListener("DOMContentLoaded", run);
