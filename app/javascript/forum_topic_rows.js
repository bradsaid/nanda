// Make the whole topic row clickable on the forum index, not just the title.
//
// The title link stays the real, focusable link — this only widens the target
// for pointer users. Clicks that land on any other link or button inside the
// row (the author, the last poster) are left alone, and modifier or middle
// clicks open a new tab the way a normal link would.

function navigate(row, event) {
  const href = row.dataset.topicHref;
  if (!href) return;
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.button === 1) {
    window.open(href, "_blank", "noopener");
  } else {
    window.location.href = href;
  }
}

function onRowClick(event) {
  const row = event.target.closest(".forum-topic-row");
  if (!row) return;
  // Let real links, buttons and form controls behave normally.
  if (event.target.closest("a, button, input, label, select, textarea")) return;
  // Don't fight a text selection the user is making.
  if (window.getSelection && window.getSelection().toString().length > 0) return;
  event.preventDefault();
  navigate(row, event);
}

function attachTopicRows() {
  document.querySelectorAll(".forum-topic-row").forEach((row) => {
    if (row.dataset.rowReady) return;
    row.dataset.rowReady = "1";
    row.addEventListener("click", onRowClick);
    row.addEventListener("auxclick", (e) => { if (e.button === 1) onRowClick(e); });
  });
}

document.addEventListener("turbo:load", attachTopicRows);
document.addEventListener("DOMContentLoaded", attachTopicRows);
export {};
