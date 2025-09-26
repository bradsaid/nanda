export function injectJsonLd(schema) {
  if (!schema) return;
  const el = document.createElement("script");
  el.type = "application/ld+json";
  el.text = JSON.stringify(schema);
  document.head.appendChild(el);
}

export function readJson(selector) {
  const tag = document.querySelector(selector);
  if (!tag) return null;
  try { return JSON.parse(tag.textContent); } catch { return null; }
}
