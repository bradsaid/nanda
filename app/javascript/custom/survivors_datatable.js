(() => {
  let wired = false;

  function ready() {
    const $ = window.jQuery || window.$;
    return $ && $.fn && $.fn.DataTable;
  }

  function initOnce() {
    if (!ready()) return;
    const $ = window.jQuery;

    const $table = $("#survivors-table");
    if (!$table.length) return;
    if ($.fn.dataTable.isDataTable($table)) return;

    $.fn.dataTable.ext.errMode = "console";

    const ajaxUrl = $table.attr("data-ajax-url");
    if (!ajaxUrl) {
        console.warn("survivors_datatable: missing data-ajax-url on #survivors-table");
        return;
    }

    const dt = $table.DataTable({
        processing: true,
        serverSide: true,
        ajax: ajaxUrl,
        pageLength: 25,
        lengthMenu: [10, 25, 50, 100],
        order: [],
        columns: [
        { name: "name" },
        { name: "episodes", searchable: false },
        { name: "links", orderable: false, searchable: false },
        ],
        stateSave: true,
    });

    const $input = $("#survivor-q");
    if ($input.length) {
        $input.on("input", function () {
        dt.search(this.value).draw();
        });
    }
    }

  function destroyIfPresent() {
    if (!ready()) return;
    const $ = window.jQuery;
    const $table = $("#survivors-table");
    if ($table.length && $.fn.dataTable.isDataTable($table)) {
      $table.DataTable().destroy();
      $table.find("tbody").empty();
    }
  }

  function wire() {
    if (wired) return; wired = true;

    // try immediately, then poll a few times in case CDN is slow
    let tries = 0;
    const t = setInterval(() => {
      initOnce();
      if (ready() && $.fn.dataTable.isDataTable && $("#survivors-table").length && $.fn.dataTable.isDataTable($("#survivors-table"))) {
        clearInterval(t);
      }
      if (++tries > 20) clearInterval(t); // ~2s
    }, 100);

    document.addEventListener("turbo:load", initOnce);
    document.addEventListener("turbo:render", initOnce);
    document.addEventListener("turbo:frame-load", initOnce);
    document.addEventListener("turbo:before-cache", destroyIfPresent);

    if (document.readyState !== "loading") setTimeout(initOnce, 0);
    window.addEventListener("load", initOnce);
    document.addEventListener("DOMContentLoaded", initOnce);
  }

  wire();
})();
