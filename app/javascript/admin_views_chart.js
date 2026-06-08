// Renders the admin dashboard's Views vs Unique Visitors line chart.
// Reads its data from a JSON blob in #admin-views-chart-data and draws into
// the <canvas id="admin-views-chart"> element. Safe to import on any page —
// it exits early if either element is missing.

import Chart from "chart.js";

function init() {
  const canvas = document.getElementById("admin-views-chart");
  const dataEl = document.getElementById("admin-views-chart-data");
  if (!canvas || !dataEl) return;

  if (typeof Chart !== "function") {
    console.error("[admin_views_chart] Chart.js failed to load:", Chart);
    return;
  }

  let payload;
  try { payload = JSON.parse(dataEl.textContent); } catch (e) {
    console.error("[admin_views_chart] payload parse error:", e);
    return;
  }
  if (!payload || !payload.labels) {
    console.warn("[admin_views_chart] empty payload:", payload);
    return;
  }

  const ctx = canvas.getContext("2d");
  new Chart(ctx, {
    type: "line",
    data: {
      labels: payload.labels,
      datasets: [
        {
          label: "Views",
          data: payload.views,
          borderColor: "#0e3f24",
          backgroundColor: "rgba(14, 63, 36, 0.15)",
          fill: true,
          tension: 0.25,
          pointRadius: 3
        },
        {
          label: "Unique Visitors",
          data: payload.uniques,
          borderColor: "#b88070",
          backgroundColor: "rgba(184, 128, 112, 0.15)",
          fill: true,
          tension: 0.25,
          pointRadius: 3
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

document.addEventListener("DOMContentLoaded", init);
