import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select"];

  jump() {
    const id = this.selectTarget.value;
    if (!id) return;
    const el = document.getElementById(id);
    if (!el) return;
    el.scrollIntoView({ behavior: "smooth", block: "start" });
    // Optional: reset or keep selection
    // this.selectTarget.value = "";
    history.replaceState(null, "", `#${id}`);
  }
}