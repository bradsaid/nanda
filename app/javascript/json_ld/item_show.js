import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#item-jsonld-data");
  if (!d) return;
  injectJsonLd({
    "@context":"https://schema.org",
    "@type":"Product",
    "name": d.name,
    "category": d.category || undefined,
    "url": window.location.href,
    "description": `${d.name} appearances across Naked and Afraid episodes.`,
    "additionalProperty": [
      { "@type":"PropertyValue","name":"Given in episodes","value": d.given },
      { "@type":"PropertyValue","name":"Brought in episodes","value": d.brought },
      { "@type":"PropertyValue","name":"Total appearances","value": d.total },
      ...(d.country ? [{ "@type":"PropertyValue","name":"Filtered country","value": d.country }] : [])
    ],
    "subjectOf": (d.episodes || []).map(ep => ({
      "@type":"TVEpisode","name": ep.name,"url": ep.url,
      "partOfSeries": { "@type":"TVSeries","name": ep.series },
      "seasonNumber": ep.season,"episodeNumber": ep.number
    }))
  });
}

document.addEventListener("DOMContentLoaded", run);
