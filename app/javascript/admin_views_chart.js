// Renders the admin dashboard's Views vs Unique Visitors line chart.
// Preloads the full daily series from the server, then slices client-side
// based on a range slider so dragging is instant. Also overlays a linear-
// regression trend line on the Views series.

// Chart.js is loaded via a plain <script> tag on the admin dashboard so
// it exposes window.Chart globally. We read from window instead of using
// an ES-module import — the importmap+CDN dance was breaking because
// Chart.js's ESM bundle has absolute-path imports that browsers resolve
// against the page origin (404'd against our domain).

let chartInstance = null;
let fullPayload = null;

function linearTrend(values) {
  const n = values.length;
  if (n < 2) return values.map(() => null);
  let sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
  for (let i = 0; i < n; i++) {
    sumX += i;
    sumY += values[i];
    sumXY += i * values[i];
    sumXX += i * i;
  }
  const denom = n * sumXX - sumX * sumX;
  if (denom === 0) return values.map(() => sumY / n);
  const slope = (n * sumXY - sumX * sumY) / denom;
  const intercept = (sumY - slope * sumX) / n;
  return values.map((_, i) => Math.max(0, intercept + slope * i));
}

function sliceWindow(payload, days) {
  const n = payload.labels.length;
  const take = Math.min(Math.max(1, days), n);
  return {
    labels:  payload.labels.slice(n - take),
    views:   payload.views.slice(n - take),
    uniques: payload.uniques.slice(n - take)
  };
}

function buildChart(canvas, sliced) {
  const ctx = canvas.getContext("2d");
  const trend = linearTrend(sliced.views);
  return new window.Chart(ctx, {
    type: "line",
    data: {
      labels: sliced.labels,
      datasets: [
        {
          label: "Views",
          data: sliced.views,
          borderColor: "#0e3f24",
          backgroundColor: "rgba(14, 63, 36, 0.15)",
          fill: true,
          tension: 0.25,
          pointRadius: 2
        },
        {
          label: "Unique Visitors",
          data: sliced.uniques,
          borderColor: "#b88070",
          backgroundColor: "rgba(184, 128, 112, 0.15)",
          fill: true,
          tension: 0.25,
          pointRadius: 2
        },
        {
          label: "Views Trend",
          data: trend,
          borderColor: "rgba(33, 37, 41, 0.65)",
          borderDash: [6, 4],
          borderWidth: 2,
          backgroundColor: "transparent",
          fill: false,
          pointRadius: 0,
          tension: 0
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { position: "bottom" },
        tooltip: {
          callbacks: {
            label: function(ctx) {
              return `${ctx.dataset.label}: ${ctx.parsed.y.toLocaleString()}`;
            }
          }
        }
      },
      scales: {
        x: { grid: { display: false } },
        y: { beginAtZero: true, ticks: { precision: 0 } }
      }
    }
  });
}

function refresh(days) {
  if (!chartInstance || !fullPayload) return;
  const sliced = sliceWindow(fullPayload, days);
  const trend  = linearTrend(sliced.views);
  chartInstance.data.labels = sliced.labels;
  chartInstance.data.datasets[0].data = sliced.views;
  chartInstance.data.datasets[1].data = sliced.uniques;
  chartInstance.data.datasets[2].data = trend;
  chartInstance.update("none");

  const label = document.getElementById("admin-views-chart-range-label");
  if (label) label.textContent = `Last ${days} ${days === 1 ? "day" : "days"}`;
}

function init() {
  const canvas = document.getElementById("admin-views-chart");
  const dataEl = document.getElementById("admin-views-chart-data");
  if (!canvas || !dataEl) return;

  // Re-init on Turbo navigation: destroy any previous chart bound to this canvas.
  if (chartInstance) {
    try { chartInstance.destroy(); } catch (_) { /* noop */ }
    chartInstance = null;
  }

  if (typeof window.Chart !== "function") {
    console.error("[admin_views_chart] Chart.js global not present — UMD script may not have loaded yet");
    return;
  }

  try { fullPayload = JSON.parse(dataEl.textContent); } catch (e) {
    console.error("[admin_views_chart] payload parse error:", e);
    return;
  }
  if (!fullPayload || !fullPayload.labels) {
    console.warn("[admin_views_chart] empty payload:", fullPayload);
    return;
  }

  const slider = document.getElementById("admin-views-chart-range");
  const initialDays = slider ? Number(slider.value) : Math.min(30, fullPayload.labels.length);
  chartInstance = buildChart(canvas, sliceWindow(fullPayload, initialDays));

  if (slider) {
    slider.addEventListener("input", (e) => {
      refresh(Number(e.target.value));
    });
  }
}

// ES modules execute deferred, so DOMContentLoaded may have already fired by
// the time this file runs. Call init() right away in that case, otherwise wait
// for the DOM. Also re-init on Turbo navigations so going from another admin
// page back to /admin re-builds the chart.
if (document.readyState !== "loading") {
  init();
} else {
  document.addEventListener("DOMContentLoaded", init);
}
document.addEventListener("turbo:load", init);
