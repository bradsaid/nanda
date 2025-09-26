
import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#item-type-jsonld-data");
  if (!d) return;
  injectJsonLd({
    "@context":"https://schema.org","@type":"ItemList",
    "name": `${d.type} Items${d.country ? " in " + d.country : ""}`,
    "numberOfItems": d.items_count,
    "description": `Given in ${d.given} episode(s), brought in ${d.brought}.`,
    "itemListElement": (d.items || []).map((it, i) => ({
      "@type":"ListItem","position": i + 1,"url": it.url,"name": it.name
    }))
  });
}

document.addEventListener("DOMContentLoaded", run);
