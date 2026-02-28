// Tracks time spent on each page and pings the server periodically.
(function () {
  const meta = document.querySelector('meta[name="page-view-id"]');
  if (!meta) return;

  const pageViewId = meta.content;
  if (!pageViewId || pageViewId === "") return;

  const startTime = Date.now();
  let lastSent = 0;

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
  const interval = setInterval(sendPing, 15000);

  // Ping when tab becomes hidden or page unloads
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "hidden") {
      sendPing();
    }
  });

  // Turbo navigation (SPA-style page change)
  document.addEventListener("turbo:before-visit", function () {
    sendPing();
    clearInterval(interval);
  });

  // Fallback for hard navigation
  window.addEventListener("beforeunload", sendPing);
})();
