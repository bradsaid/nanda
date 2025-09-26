import { injectJsonLd, readJson } from "json_ld/helpers";

export function run() {
  const d = readJson("#survivor-jsonld-data");
  if (!d) return;
  injectJsonLd([
    {
      "@context":"https://schema.org",
      "@type":"Person",
      "name": d.name, "url": window.location.href,
      "image": d.image || undefined,
      "description": `${d.name} from Naked and Afraid with ${d.episodes} episode(s) and ${d.challenges} challenge(s).`,
      "sameAs": d.sameAs || []
    },
    {
      "@context":"https://schema.org",
      "@type":"BreadcrumbList",
      "itemListElement":[
        { "@type":"ListItem","position":1,"name":"Home","item": d.root_url },
        { "@type":"ListItem","position":2,"name":"Survivors","item": d.survivors_url },
        { "@type":"ListItem","position":3,"name": d.name,"item": window.location.href }
      ]
    }
  ]);
}

document.addEventListener("DOMContentLoaded", run);
