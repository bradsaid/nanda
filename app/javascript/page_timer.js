// Tracks ACTIVE time spent on each page (ignores idle time).
// User is considered idle after 30 seconds of no interaction.
function initPageTimer() {
  const match = document.cookie.match(/(?:^|;\s*)_pv_id=(\d+)/);
  if (!match) return;

  const pageViewId = match[1];
  document.cookie = "_pv_id=; path=/; max-age=0";

  const IDLE_THRESHOLD = 30000; // 30 seconds of no activity = idle
  const MAX_DURATION = 1800;    // stop tracking after 30 minutes
  let activeSeconds = 0;
  let lastTick = Date.now();
  let lastActivity = Date.now();
  let lastSent = 0;
  let timer = null;
  let tickTimer = null;

  // Track user activity
  function onActivity() {
    lastActivity = Date.now();
  }

  var activityEvents = ["mousemove", "scroll", "keydown", "click", "touchstart"];
  activityEvents.forEach(function (evt) {
    document.addEventListener(evt, onActivity, { passive: true });
  });

  // Every second, check if user is active and accumulate time
  tickTimer = setInterval(function () {
    var now = Date.now();
    if (now - lastActivity < IDLE_THRESHOLD) {
      activeSeconds += Math.round((now - lastTick) / 1000);
    }
    lastTick = now;
    // Stop tracking after max duration
    if (activeSeconds >= MAX_DURATION) {
      activeSeconds = MAX_DURATION;
      cleanup();
    }
  }, 1000);

  function sendPing() {
    if (activeSeconds <= lastSent) return;
    lastSent = activeSeconds;

    var data = new FormData();
    data.append("page_view_id", pageViewId);
    data.append("seconds", activeSeconds);

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
    clearInterval(tickTimer);
    activityEvents.forEach(function (evt) {
      document.removeEventListener(evt, onActivity);
    });
  }

  // Ping when tab becomes hidden
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "hidden") {
      sendPing();
    }
  });

  // Turbo navigation
  document.addEventListener("turbo:before-visit", cleanup, { once: true });

  // Hard navigation
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
