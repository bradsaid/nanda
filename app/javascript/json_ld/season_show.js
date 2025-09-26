import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#season-jsonld-data");
  if (!d) return;
  const list = (d.episodes || []).map((ep, i) => ({
    "@type":"ListItem","position": i + 1,"url": ep.url,"name": ep.name,
    "additionalProperty": [
      ep.season ? { "@type":"PropertyValue","name":"Season","value": ep.season } : undefined,
      ep.number ? { "@type":"PropertyValue","name":"Episode","value": ep.number } : undefined,
      ep.air_date ? { "@type":"PropertyValue","name":"Air date","value": ep.air_date } : undefined
    ].filter(Boolean)
  }));
  injectJsonLd([
    { "@context":"https://schema.org","@type":"TVSeason","name": d.label,
      "seasonNumber": d.season, "partOfSeries": { "@type":"TVSeries","name": d.series },
      "numberOfEpisodes": d.count, "startDate": d.first_air || undefined, "endDate": d.last_air || undefined,
      "url": window.location.href },
    (list.length ? { "@context":"https://schema.org","@type":"ItemList","name": `${d.label} — Episodes`,
      "itemListElement": list } : undefined)
  ].filter(Boolean));
}

document.addEventListener("DOMContentLoaded", run);
