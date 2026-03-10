// Episode admin form: dynamic add/remove for participants, items, food sources, shelters
function initEpisodeForm() {
  var form = document.querySelector("#participants-table");
  if (!form) return;

  // ===== Add Participant =====
  document.getElementById("add-participant")?.addEventListener("click", function() {
    var tbody = document.querySelector("#participants-table tbody");
    var tmpl  = document.getElementById("participant-template");
    var idx   = Date.now();
    var html  = tmpl.innerHTML.replace(/NEW_IDX/g, idx);
    tbody.insertAdjacentHTML("beforeend", html);
  });

  // ===== Add Food Source =====
  document.getElementById("add-food-source")?.addEventListener("click", function() {
    var tbody = document.querySelector("#food-sources-table tbody");
    var tmpl  = document.getElementById("food-source-template");
    var idx   = Date.now();
    var html  = tmpl.innerHTML.replace(/FS_IDX/g, idx);
    tbody.insertAdjacentHTML("beforeend", html);
  });

  // ===== Add Shelter =====
  document.getElementById("add-shelter")?.addEventListener("click", function() {
    var tbody = document.querySelector("#shelters-table tbody");
    var tmpl  = document.getElementById("shelter-template");
    var idx   = Date.now();
    var html  = tmpl.innerHTML.replace(/SH_IDX/g, idx);
    tbody.insertAdjacentHTML("beforeend", html);
  });

  // ===== Event delegation for the whole form area =====
  document.addEventListener("click", function(e) {
    // Add item to a participant
    var addItemBtn = e.target.closest(".add-item-btn");
    if (addItemBtn) {
      var appIdx = addItemBtn.getAttribute("data-appearance-idx");
      var container = addItemBtn.parentElement.querySelector(".items-container");
      if (!container) return;
      var tmpl = document.getElementById("item-template");
      var itemIdx = Date.now();
      var html = tmpl.innerHTML.replace(/APP_IDX/g, appIdx).replace(/ITEM_IDX/g, itemIdx);
      container.insertAdjacentHTML("beforeend", html);
      return;
    }

    // Remove item
    var removeItemBtn = e.target.closest(".remove-item-btn");
    if (removeItemBtn) {
      var entry = removeItemBtn.closest(".item-entry");
      if (!entry) return;
      var destroyField = entry.querySelector("input[name*='_destroy']");
      var idField = entry.querySelector("input[name*='[id]']");
      if (destroyField && idField) {
        destroyField.value = "1";
        entry.style.display = "none";
      } else {
        entry.remove();
      }
      return;
    }

    // Remove participant
    var removePartBtn = e.target.closest(".remove-participant-btn");
    if (removePartBtn) {
      var row = removePartBtn.closest("tr.participant-row");
      if (!row) return;
      var itemsRow = row.nextElementSibling;
      var destroyField = row.querySelector("input[name*='_destroy']");
      if (destroyField && row.querySelector("input[name*='[id]']")) {
        destroyField.value = "1";
        row.style.display = "none";
        if (itemsRow && itemsRow.classList.contains("items-row")) itemsRow.style.display = "none";
      } else {
        if (itemsRow && itemsRow.classList.contains("items-row")) itemsRow.remove();
        row.remove();
      }
      return;
    }

    // Remove food source or shelter row
    var removeRowBtn = e.target.closest(".remove-row-btn");
    if (removeRowBtn) {
      var row = removeRowBtn.closest("tr");
      var destroyField = row.querySelector("input[name*='_destroy']");
      if (destroyField && row.querySelector("input[name*='[id]']")) {
        destroyField.value = "1";
        row.style.display = "none";
      } else {
        row.remove();
      }
      return;
    }
  });
}

document.addEventListener("turbo:load", initEpisodeForm);
document.addEventListener("DOMContentLoaded", initEpisodeForm);
