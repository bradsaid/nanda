// On the Locations index, when the page loads with a search query in the URL
// (?q=...), scroll the country grid into view instead of leaving the user at
// the top of the page. GET form submissions strip URL fragments, so the
// #countries-results anchor on the form's action URL is lost — this restores
// the equivalent behaviour without changing the markup.

function scrollToCountriesResultsIfSearched() {
  if (window.location.pathname !== "/locations") return;
  var params = new URLSearchParams(window.location.search);
  var q = params.get("q");
  if (!q || q.trim() === "") return;
  var target = document.getElementById("countries-results");
  if (!target) return;
  // Defer one frame so layout settles before measuring scroll position.
  requestAnimationFrame(function() {
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  });
}

document.addEventListener("turbo:load", scrollToCountriesResultsIfSearched);
document.addEventListener("DOMContentLoaded", scrollToCountriesResultsIfSearched);
export {};
