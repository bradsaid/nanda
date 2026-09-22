// Widens the click target for a row or card that has one obvious destination.
//
// Used by the topic list and the member directory. The real link inside stays
// the focusable, screen-reader-visible one — this only helps pointer users.
// Anything that is itself a link, button or form control keeps its own
// behaviour, an in-progress text selection is never interrupted, and modifier
// or middle clicks open a new tab the way a normal link would.

function navigate(el, event) {
  const href = el.dataset.clickHref;
  if (!href) return;
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.button === 1) {
    window.open(href, "_blank", "noopener");
  } else {
    window.location.href = href;
  }
}

function onClick(event) {
  const el = event.target.closest("[data-click-href]");
  if (!el) return;
  if (event.target.closest("a, button, input, label, select, textarea")) return;
  if (window.getSelection && window.getSelection().toString().length > 0) return;
  event.preventDefault();
  navigate(el, event);
}

function attachClickTargets() {
  document.querySelectorAll("[data-click-href]").forEach((el) => {
    if (el.dataset.clickReady) return;
    el.dataset.clickReady = "1";
    el.addEventListener("click", onClick);
    el.addEventListener("auxclick", (e) => { if (e.button === 1) onClick(e); });
  });
}

document.addEventListener("turbo:load", attachClickTargets);
document.addEventListener("DOMContentLoaded", attachClickTargets);
export {};
