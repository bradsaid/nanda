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

function getEpisodeAppearances() {
  var list = [];
  var rows = document.querySelectorAll("#participants-table tbody tr.participant-row");
  rows.forEach(function(row) {
    if (row.style.display === "none") return;
    var idx = row.getAttribute("data-appearance-idx");
    var select = row.querySelector("select[name*='[survivor_id]']");
    if (idx && select && select.value) {
      var opt = select.options[select.selectedIndex];
      list.push({ idx: idx, id: select.value, name: opt.text });
    }
  });
  return list;
}

function updateBulkGivenRecipients() {
  var container = document.getElementById("bulk-given-recipients");
  if (!container) return;
  var prevChecked = {};
  container.querySelectorAll(".bulk-given-recipient:checked").forEach(function(cb) {
    prevChecked[cb.value] = true;
  });
  var appearances = getEpisodeAppearances();
  if (appearances.length === 0) {
    container.innerHTML = '<span class="text-muted small">No participants yet</span>';
    return;
  }
  var html = '';
  html += '<div class="form-check form-check-inline me-2">';
  html += '<input type="checkbox" class="form-check-input" id="bulk-given-all">';
  html += '<label class="form-check-label small fw-bold" for="bulk-given-all">All</label>';
  html += '</div>';
  appearances.forEach(function(a) {
    var cbId = 'bulk_given_app_' + a.idx;
    var span = document.createElement('span');
    span.textContent = a.name;
    var checkedAttr = prevChecked[a.idx] ? ' checked' : '';
    html += '<div class="form-check form-check-inline">';
    html += '<input type="checkbox" class="form-check-input bulk-given-recipient" value="' + a.idx + '" id="' + cbId + '"' + checkedAttr + '>';
    html += '<label class="form-check-label small" for="' + cbId + '">' + span.innerHTML + '</label>';
    html += '</div>';
  });
  container.innerHTML = html;
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
  if (form.dataset.epFormInit === "1") return;
  form.dataset.epFormInit = "1";

  // ===== No-Traps toggle =====
  var noTrapsCb   = document.getElementById("episode_no_traps");
  var trapsBody   = document.getElementById("traps-section-body");
  function syncTrapsVisibility() {
    if (!noTrapsCb || !trapsBody) return;
    trapsBody.style.display = noTrapsCb.checked ? "none" : "";
  }
  syncTrapsVisibility();
  noTrapsCb?.addEventListener("change", syncTrapsVisibility);

  // ===== Add Participant =====
  document.getElementById("add-participant")?.addEventListener("click", function() {
    var tbody = document.querySelector("#participants-table tbody");
    var tmpl  = document.getElementById("participant-template");
    var idx   = Date.now();
    var html  = tmpl.innerHTML.replace(/NEW_IDX/g, idx);
    tbody.insertAdjacentHTML("beforeend", html);
    updateBulkGivenRecipients();
  });

  // ===== Copy participants from previous episode in this season =====
  var seasonSelect = document.getElementById("episode_season_id_select");
  var copyControls = document.getElementById("copy-participants-controls");
  var copyBtn      = document.getElementById("copy-prev-participants");

  function toggleCopyControls() {
    if (!copyControls) return;
    copyControls.style.display = (seasonSelect && seasonSelect.value) ? "" : "none";
  }
  toggleCopyControls();

  // On season change, auto-fill metadata fields (only for continuous-story seasons
  // and only when the target field is empty — so we don't overwrite admin edits).
  async function autoFillFromSeason() {
    if (!seasonSelect || !seasonSelect.value) return;
    try {
      var res = await fetch("/admin/seasons/" + seasonSelect.value + "/latest_episode_participants.json", {
        headers: { "Accept": "application/json" }
      });
      if (!res.ok) return;
      var data = await res.json();
      if (!data || !data.continuous_story) return;

      function setIfEmpty(elId, value) {
        if (value == null) return;
        var el = document.getElementById(elId);
        if (!el) return;
        var current = (el.value || "").trim();
        if (current === "") {
          el.value = String(value);
        }
      }

      setIfEmpty("episode_location_id",             data.location_id);
      setIfEmpty("episode_scheduled_days",          data.scheduled_days);
      setIfEmpty("episode_participant_arrangement", data.participant_arrangement);
      setIfEmpty("episode_type_modifiers",          data.type_modifiers);
    } catch (e) {
      console.warn("[auto-fill from season]", e);
    }
  }

  seasonSelect?.addEventListener("change", function() {
    toggleCopyControls();
    autoFillFromSeason();
  });

  copyBtn?.addEventListener("click", async function() {
    if (!seasonSelect || !seasonSelect.value) return;
    copyBtn.disabled = true;
    var original_label = copyBtn.textContent;
    copyBtn.textContent = "Loading…";
    try {
      var res = await fetch("/admin/seasons/" + seasonSelect.value + "/latest_episode_participants.json", {
        headers: { "Accept": "application/json" }
      });
      if (!res.ok) throw new Error("HTTP " + res.status);
      var data = await res.json();
      var participants = data.participants || [];
      if (participants.length === 0) {
        alert(data.note || "No previous episode in this season.");
        return;
      }

      var tbody = document.querySelector("#participants-table tbody");
      var tmpl  = document.getElementById("participant-template");
      participants.forEach(function(p, i) {
        var idx  = Date.now() + i;
        var html = tmpl.innerHTML.replace(/NEW_IDX/g, idx);
        tbody.insertAdjacentHTML("beforeend", html);
        var newRow = tbody.lastElementChild.previousElementSibling || tbody.lastElementChild;
        // The template renders TWO rows (participant + items-row). Walk back to the participant-row.
        var participantRow = tbody.querySelector("tr.participant-row[data-appearance-idx='" + idx + "']");
        if (!participantRow) return;
        var survivorSelect = participantRow.querySelector("select[name*='[survivor_id]']");
        if (survivorSelect) survivorSelect.value = String(p.survivor_id);
        var roleSelect = participantRow.querySelector("select[name*='[role]']");
        if (roleSelect && p.role) roleSelect.value = String(p.role);
        var startInput = participantRow.querySelector("input[name*='[starting_psr]']");
        if (startInput && p.starting_psr != null) startInput.value = String(p.starting_psr);
      });

      updateBulkGivenRecipients();
      var note = data.from_episode ? ("Copied " + participants.length + " participants from \"" + data.from_episode.title + "\".") : ("Copied " + participants.length + " participants.");
      copyBtn.textContent = "✓ " + note;
      setTimeout(function() { copyBtn.textContent = original_label; copyBtn.disabled = false; }, 3500);
    } catch (e) {
      console.error("[copy-participants]", e);
      alert("Could not load previous participants.");
      copyBtn.textContent = original_label;
      copyBtn.disabled = false;
    }
  });

  // ===== Quick Add Given Item — fan one item out to multiple survivors =====
  updateBulkGivenRecipients();

  document.getElementById("bulk-given-add")?.addEventListener("click", function() {
    var itemSelect = document.getElementById("bulk-given-item");
    var qtyInput   = document.getElementById("bulk-given-qty");
    if (!itemSelect || !itemSelect.value) {
      alert("Pick an item first.");
      return;
    }
    var qty = parseInt(qtyInput.value, 10) || 1;
    var itemId = itemSelect.value;
    var checked = document.querySelectorAll(".bulk-given-recipient:checked");
    if (checked.length === 0) {
      alert("Pick at least one survivor.");
      return;
    }
    var tmpl = document.getElementById("item-template");
    checked.forEach(function(cb, i) {
      var appIdx = cb.value;
      var container = document.querySelector(".items-container[data-appearance-idx='" + appIdx + "']");
      if (!container) return;
      var itemIdx = Date.now() + i;
      var html = tmpl.innerHTML.replace(/APP_IDX/g, appIdx).replace(/ITEM_IDX/g, itemIdx);
      container.insertAdjacentHTML("beforeend", html);
      var entry  = container.lastElementChild;
      var itemFld = entry.querySelector("select[name*='[item_id]']");
      var srcFld  = entry.querySelector("select[name*='[source]']");
      var qtyFld  = entry.querySelector("input[name*='[quantity]']");
      if (itemFld) itemFld.value = itemId;
      if (srcFld)  srcFld.value  = "given";
      if (qtyFld)  qtyFld.value  = qty;
    });
    itemSelect.value = "";
  });

  // Toggle all recipients
  document.addEventListener("change", function(e) {
    if (e.target.id === "bulk-given-all") {
      var checked = e.target.checked;
      document.querySelectorAll(".bulk-given-recipient").forEach(function(cb) { cb.checked = checked; });
    }
    // Refresh recipient list when a participant's survivor changes
    if (e.target.matches("select[name*='[survivor_id]']")) {
      updateBulkGivenRecipients();
    }
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
      updateBulkGivenRecipients();
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
