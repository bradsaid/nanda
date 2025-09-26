import { injectJsonLd } from "json_ld/helpers"; // same helper you’re using elsewhere

function readPayload(id) {
  const el = document.getElementById(id);
  if (!el) return null;
  try { return JSON.parse(el.textContent); } catch { return null; }
}

document.addEventListener("DOMContentLoaded", () => {
  const d = readPayload("about-jsonld-data");
  if (!d) return;

  injectJsonLd({
    "@context": "https://schema.org",
    "@type": "AboutPage",
    "name": d.name || "About",
    "description": d.description || "",
    "url": window.location.href
  });
});
