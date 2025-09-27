import { injectJsonLd } from "json_ld/helpers";

export function run() {
  const siteName = "Naked & Afraid Fan Database";
  const heroImg  = "/favicon.png";
  const schema = [
    { "@context":"https://schema.org","@type":"WebSite","name":siteName,"url":window.location.origin },
    { "@context":"https://schema.org","@type":"CollectionPage","name":siteName,
      "description":"Fan-maintained guide to episodes, survivors, items, and locations.",
      "url":window.location.href,"image":heroImg }
  ];
  injectJsonLd(schema);
}

document.addEventListener("DOMContentLoaded", run);
