// Tracks time spent on each page and pings the server periodically.
function initPageTimer() {
  // Read page_view_id from cookie set by after_action
  const match = document.cookie.match(/(?:^|;\s*)_pv_id=(\d+)/);
  if (!match) return;

  const pageViewId = match[1];
  // Clear it so we don't re-use on next Turbo navigation before new cookie arrives
  document.cookie = "_pv_id=; path=/; max-age=0";

  const startTime = Date.now();
  let lastSent = 0;
  let timer = null;

  function elapsed() {
    return Math.round((Date.now() - startTime) / 1000);
  }

  function sendPing() {
    const seconds = elapsed();
    if (seconds <= lastSent) return;
    lastSent = seconds;

    const data = new FormData();
    data.append("page_view_id", pageViewId);
    data.append("seconds", seconds);

    if (navigator.sendBeacon) {
      navigator.sendBeacon("/page_view_ping", data);
    } else {
      fetch("/page_view_ping", { method: "POST", body: data, keepalive: true });
    }
  }

  // Ping every 15 seconds
  timer = setInterval(sendPing, 15000);

  function cleanup() {
    sendPing();
    clearInterval(timer);
  }

  // Ping when tab becomes hidden
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "hidden") {
      sendPing();
    }
  });

  // Turbo navigation (SPA-style page change)
  document.addEventListener("turbo:before-visit", cleanup, { once: true });

  // Fallback for hard navigation
  window.addEventListener("beforeunload", sendPing);
}

// Run on initial page load
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initPageTimer);
} else {
  initPageTimer();
}

// Re-run after each Turbo navigation
document.addEventListener("turbo:load", initPageTimer);
