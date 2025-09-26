import { injectJsonLd } from "json_ld/helpers";

function readJson(selector) {
  const el = document.querySelector(selector);
  if (!el) return null;
  try { return JSON.parse(el.textContent); } catch { return null; }
}

export function run() {
  const d = readJson("#survivors-index-jsonld-data");
  if (!d) return;

  const schema = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "name": "Naked and Afraid Survivors",
    "numberOfItems": d.count,
    "itemListElement": (d.survivors || []).map((p, i) => ({
      "@type": "ListItem",
      "position": i + 1,
      "url": p.url,
      "name": p.name,
      "item": {
        "@type": "Person",
        "name": p.name,
        "url": p.url,
        "image": p.image || undefined,
        "additionalProperty": [
          { "@type": "PropertyValue", "name": "Episodes (total)", "value": p.episodes_total },
          { "@type": "PropertyValue", "name": "Challenges", "value": p.challenges }
        ]
      }
    }))
  };

  injectJsonLd(schema);
}

document.addEventListener("DOMContentLoaded", run);
