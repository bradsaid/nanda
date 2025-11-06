// app/javascript/controllers/season_sort_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { baseUrl: String, current: String };

  change(event) {
    const val = event.target.value;
    const url =
      val === "" ? this.baseUrlValue : `${this.baseUrlValue}?sort=${encodeURIComponent(val)}`;
    window.location.assign(url);
  }

  connect() {
    if (this.hasCurrentValue) {
      const sel = this.element.querySelector("select");
      if (sel) sel.value = this.currentValue;
    }
  }
}
