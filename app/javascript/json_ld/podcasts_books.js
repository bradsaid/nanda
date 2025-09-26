import { injectJsonLd } from "./inject";

function readJson(selector) {
  const el = document.querySelector(selector);
  if (!el) return null;
  try { return JSON.parse(el.textContent); } catch { return null; }
}

document.addEventListener("DOMContentLoaded", () => {
  const d = readJson("#podcasts-books-jsonld-data");
  if (!d) return;

  // CollectionPage describing this index
  injectJsonLd({
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "name": "Naked & Afraid Podcasts and Books",
    "url": d.page_url || window.location.href,
    "description": "Fan podcasts about Naked & Afraid and recommended books by Ky Furneaux."
  });

  // ItemList of PodcastSeries
  injectJsonLd({
    "@context": "https://schema.org",
    "@type": "ItemList",
    "name": "Naked & Afraid Podcasts",
    "itemListElement": (d.podcasts || []).map((p, i) => ({
      "@type": "ListItem",
      "position": i + 1,
      "item": {
        "@type": "PodcastSeries",
        "name": p.name,
        "sameAs": p.urls
      }
    }))
  });

  // ItemList of Books (with author)
  injectJsonLd({
    "@context": "https://schema.org",
    "@type": "ItemList",
    "name": "Books by Ky Furneaux",
    "itemListElement": (d.books || []).map((b, i) => ({
      "@type": "ListItem",
      "position": i + 1,
      "item": {
        "@type": "Book",
        "name": b.name,
        "author": d.author?.name ? {
          "@type": "Person",
          "name": d.author.name,
          "url": d.author.url || undefined
        } : undefined,
        "offers": b.url ? {
          "@type": "Offer",
          "url": b.url
        } : undefined
      }
    }))
  });
});
