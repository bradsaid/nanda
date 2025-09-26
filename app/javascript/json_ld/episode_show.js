import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#episode-jsonld-data");
  if (!d) return;
  const schema = {
    "@context":"https://schema.org",
    "@type":"TVEpisode",
    "name": d.title,
    "episodeNumber": d.episode_number,
    "partOfSeason": { "@type":"TVSeason","seasonNumber": d.season_number, "name": `${d.series_name} Season ${d.season_number}` },
    "partOfSeries": { "@type":"TVSeries","name": d.series_name },
    "datePublished": d.air_date_iso || undefined,
    "url": window.location.href,
    "locationCreated": d.location ? { "@type":"Place","name": d.location } : undefined,
    "actor": (d.actors || []).map(a => ({ "@type":"Person","name": a.name, "url": a.url })),
    "image": d.image || undefined
  };
  injectJsonLd(schema);
}

document.addEventListener("DOMContentLoaded", run);
