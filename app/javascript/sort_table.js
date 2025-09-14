function initSortableTables() {
  document.querySelectorAll("table[data-sort]").forEach((table) => {
    table.querySelectorAll("th[data-key]").forEach((th, idx) => {
      th.style.cursor = "pointer";
      th.addEventListener("click", () => {
        const key = th.dataset.key;
        const dir = th.dataset.dir === "asc" ? "desc" : "asc";
        th.dataset.dir = dir;

        const rows = Array.from(table.tBodies[0].rows);
        rows.sort((a, b) => {
          const av = a.dataset[key] || a.cells[idx].textContent.trim();
          const bv = b.dataset[key] || b.cells[idx].textContent.trim();
          const na = Number(av), nb = Number(bv);
          const cmp = (!Number.isNaN(na) && !Number.isNaN(nb)) ? (na - nb) : av.localeCompare(bv);
          return dir === "asc" ? cmp : -cmp;
        });
        rows.forEach(r => table.tBodies[0].appendChild(r));
      });
    });
  });
}
document.addEventListener("turbo:load", initSortableTables);
document.addEventListener("DOMContentLoaded", initSortableTables);
export {};
