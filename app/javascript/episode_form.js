// Episode admin form: dynamic add/remove for participants, items, food sources, traps, shelters

function getEpisodeSurvivors() {
  var survivors = [];
  var rows = document.querySelectorAll("#participants-table tbody tr.participant-row");
  rows.forEach(function(row) {
    if (row.style.display === "none") return;
    var select = row.querySelector("select[name*='[survivor_id]']");
    if (select && select.value) {
      var opt = select.options[select.selectedIndex];
      survivors.push({ id: select.value, name: opt.text });
    }
  });
  return survivors;
}

function populateBuilderCheckboxes(container, survivors, namePrefix, idPrefix, fieldName) {
  fieldName = fieldName || 'builder_ids';
  var html = '';
  survivors.forEach(function(s) {
    var cbId = idPrefix + '_' + fieldName.replace('_ids', '') + '_' + s.id;
    var escaped = document.createElement('span');
    escaped.textContent = s.name;
    html += '<div class="form-check form-check-inline">';
    html += '<input type="checkbox" class="form-check-input" name="' + namePrefix + '[' + fieldName + '][]" value="' + s.id + '" id="' + cbId + '">';
    html += '<label class="form-check-label" for="' + cbId + '">' + escaped.innerHTML + '</label>';
    html += '</div>';
  });
  container.innerHTML = html;
}

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
    var newRow = tbody.querySelector("tr.food-source-row:last-child");
    var container = newRow.querySelector(".survivor-checkboxes");
    if (container) {
      populateBuilderCheckboxes(
        container,
        getEpisodeSurvivors(),
        "episode[food_sources_attributes][" + idx + "]",
        "fs_" + idx,
        "survivor_ids"
      );
    }
  });

  // ===== Add Trap =====
  document.getElementById("add-trap")?.addEventListener("click", function() {
    var tbody = document.querySelector("#traps-table tbody");
    var tmpl  = document.getElementById("trap-template");
    var idx   = Date.now();
    var html  = tmpl.innerHTML.replace(/TRAP_IDX/g, idx);
    tbody.insertAdjacentHTML("beforeend", html);
    var newRow = tbody.querySelector("tr.trap-row:last-child");
    var container = newRow.querySelector(".builder-checkboxes");
    if (container) {
      populateBuilderCheckboxes(
        container,
        getEpisodeSurvivors(),
        "episode[episode_traps_attributes][" + idx + "]",
        "trap_" + idx
      );
    }
  });

  // ===== Add Shelter =====
  document.getElementById("add-shelter")?.addEventListener("click", function() {
    var tbody = document.querySelector("#shelters-table tbody");
    var tmpl  = document.getElementById("shelter-template");
    var idx   = Date.now();
    var html  = tmpl.innerHTML.replace(/SH_IDX/g, idx);
    tbody.insertAdjacentHTML("beforeend", html);
    var newRow = tbody.querySelector("tr.shelter-row:last-child");
    var container = newRow.querySelector(".builder-checkboxes");
    if (container) {
      populateBuilderCheckboxes(
        container,
        getEpisodeSurvivors(),
        "episode[episode_shelters_attributes][" + idx + "]",
        "shelter_" + idx
      );
    }
  });

  // ===== Toggle trap dropdown on food source method change =====
  document.addEventListener("change", function(e) {
    if (e.target.classList.contains("food-source-method")) {
      var row = e.target.closest("tr.food-source-row");
      if (!row) return;
      var trapSelect = row.querySelector(".trap-select");
      if (trapSelect) {
        trapSelect.style.display = (e.target.value === "trapped") ? "" : "none";
        if (e.target.value !== "trapped") trapSelect.value = "";
      }
    }
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

    // Remove food source, trap, or shelter row
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
