// On the Survivors index, when the page loads with a search query in the
// URL (?q=...), scroll the results table into view instead of leaving the
// user at the top of the page.

function scrollToSurvivorsResultsIfSearched() {
  if (window.location.pathname !== "/survivors") return;
  var params = new URLSearchParams(window.location.search);
  var q = params.get("q");
  if (!q || q.trim() === "") return;
  var target = document.getElementById("survivors-results");
  if (!target) return;
  // Defer one frame so layout settles before measuring scroll position.
  requestAnimationFrame(function() {
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  });
}

document.addEventListener("turbo:load", scrollToSurvivorsResultsIfSearched);
document.addEventListener("DOMContentLoaded", scrollToSurvivorsResultsIfSearched);
export {};
