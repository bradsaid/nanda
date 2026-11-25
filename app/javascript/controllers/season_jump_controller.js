import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select"];

  jump() {
    const id = this.selectTarget.value;
    if (!id) return;
    const el = document.getElementById(id);
    if (!el) {
      // The season is on another page of the (paginated) list: go to that page.
      const href = this.selectTarget.selectedOptions[0]?.dataset.href;
      if (href) window.location.assign(href);
      return;
    }
    el.scrollIntoView({ behavior: "smooth", block: "start" });
    // Optional: reset or keep selection
    // this.selectTarget.value = "";
    history.replaceState(null, "", `#${id}`);
  }
}