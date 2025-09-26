import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#seasons-index-jsonld-data");
  if (!d) return;

  const schema = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "name": "Naked and Afraid Seasons",
    "numberOfItems": d.total_seasons,
    "itemListElement": (d.sample || []).map((s, i) => ({
      "@type": "ListItem",
      "position": i + 1,
      "url": s.url,
      "name": s.name,
      "additionalProperty": [
        s.series ? { "@type":"PropertyValue", "name":"Series", "value": s.series } : undefined,
        s.number ? { "@type":"PropertyValue", "name":"Season", "value": s.number } : undefined,
        (typeof s.episodes === "number") ? { "@type":"PropertyValue", "name":"Episodes", "value": s.episodes } : undefined
      ].filter(Boolean)
    }))
  };

  injectJsonLd(schema);
}

document.addEventListener("DOMContentLoaded", run);
