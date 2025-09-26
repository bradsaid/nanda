import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#episodes-by-country-jsonld-data");
  if (!d) return;

  // 1) CollectionPage describing the page + country (Place)
  const collection = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "name": `Naked and Afraid Episodes in ${d.country}`,
    "url": window.location.href,
    "about": { "@type": "Place", "name": d.country }
  };

  // 2) ItemList of episodes (keep it lean)
  const itemList = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "name": `Episodes in ${d.country}`,
    "numberOfItems": d.count,
    "itemListElement": (d.episodes || []).map((ep, i) => ({
      "@type": "ListItem",
      "position": i + 1,
      "url": ep.url,
      "name": ep.name,
      "additionalProperty": [
        ep.series ? { "@type": "PropertyValue", "name": "Series",   "value": ep.series } : undefined,
        ep.season ? { "@type": "PropertyValue", "name": "Season",   "value": ep.season } : undefined,
        ep.number ? { "@type": "PropertyValue", "name": "Episode",  "value": ep.number } : undefined,
        ep.air_date ? { "@type": "PropertyValue","name": "Air Date","value": ep.air_date } : undefined,
        ep.location ? { "@type": "PropertyValue","name": "Location","value": ep.location } : undefined
      ].filter(Boolean)
    }))
  };

  injectJsonLd([collection, itemList]);
}

document.addEventListener("DOMContentLoaded", run);
