// On the Items index, scroll the search-results card into view when the page
// loads with ?q= in the URL (mirrors survivors_search.js behavior).

function scrollToItemsResultsIfSearched() {
  if (window.location.pathname !== "/items") return;
  var params = new URLSearchParams(window.location.search);
  var q = params.get("q");
  if (!q || q.trim() === "") return;
  var target = document.getElementById("items-results");
  if (!target) return;
  requestAnimationFrame(function() {
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  });
}

document.addEventListener("turbo:load", scrollToItemsResultsIfSearched);
document.addEventListener("DOMContentLoaded", scrollToItemsResultsIfSearched);
export {};
