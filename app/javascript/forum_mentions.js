// Typeahead for @survivalist and #episode mentions in forum composers.
//
// Typing "@matt" or "#frozen" opens a menu at the caret; choosing an entry
// replaces the token with a Markdown link, which the existing Commonmarker
// pipeline already renders and sanitises. Nothing new happens at render time.

const TRIGGERS = {
  "@": { type: "survivor", noun: "survivalist" },
  "#": { type: "episode", noun: "episode" },
};

// Trigger must start the line or follow whitespace, so an email address or a
// mid-word # never opens the menu.
const TOKEN = /(^|\s)([@#])([\p{L}\p{N}_'-]{0,40})$/u;

const MIRRORED_STYLES = [
  "boxSizing", "width", "borderTopWidth", "borderRightWidth", "borderBottomWidth",
  "borderLeftWidth", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
  "fontFamily", "fontSize", "fontWeight", "fontStyle", "letterSpacing",
  "lineHeight", "textTransform", "textIndent", "whiteSpace", "wordSpacing",
];

// Position of the caret relative to the page, via a mirror element that
// reproduces the textarea's text metrics.
function caretPoint(textarea) {
  const mirror = document.createElement("div");
  const computed = window.getComputedStyle(textarea);
  MIRRORED_STYLES.forEach((name) => { mirror.style[name] = computed[name]; });
  Object.assign(mirror.style, {
    position: "absolute", visibility: "hidden", whiteSpace: "pre-wrap",
    wordWrap: "break-word", overflow: "hidden", top: "0", left: "-9999px",
    height: "auto",
  });

  mirror.textContent = textarea.value.slice(0, textarea.selectionStart);
  const marker = document.createElement("span");
  marker.textContent = "​";
  mirror.appendChild(marker);
  document.body.appendChild(mirror);

  const box = textarea.getBoundingClientRect();
  const x = box.left + window.scrollX + marker.offsetLeft - textarea.scrollLeft;
  const y = box.top + window.scrollY + marker.offsetTop - textarea.scrollTop
            + parseFloat(computed.lineHeight || "18");
  mirror.remove();
  return { x, y };
}

class MentionMenu {
  constructor(textarea) {
    this.textarea = textarea;
    this.items = [];
    this.active = 0;
    this.token = null;
    this.seq = 0;

    this.el = document.createElement("div");
    this.el.className = "forum-mention-menu";
    this.el.setAttribute("role", "listbox");
    this.el.hidden = true;
    document.body.appendChild(this.el);

    textarea.addEventListener("input", () => this.onInput());
    textarea.addEventListener("keydown", (e) => this.onKeydown(e));
    textarea.addEventListener("blur", () => setTimeout(() => this.close(), 120));
    this.el.addEventListener("mousedown", (e) => {
      const row = e.target.closest("[data-index]");
      if (!row) return;
      e.preventDefault();
      this.choose(Number(row.dataset.index));
    });
  }

  currentToken() {
    const before = this.textarea.value.slice(0, this.textarea.selectionStart);
    const match = before.match(TOKEN);
    if (!match) return null;
    return {
      char: match[2],
      query: match[3],
      start: before.length - match[2].length - match[3].length,
    };
  }

  async onInput() {
    const token = this.currentToken();
    if (!token || !TRIGGERS[token.char] || token.query.length < 1) return this.close();

    this.token = token;
    const seq = ++this.seq;
    const url = `/forum/mentions?type=${TRIGGERS[token.char].type}&q=${encodeURIComponent(token.query)}`;

    let results = [];
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } });
      if (!response.ok) return this.close();
      results = (await response.json()).results || [];
    } catch (_e) {
      return this.close();
    }
    if (seq !== this.seq) return; // a newer keystroke already won
    this.items = results;
    this.active = 0;
    results.length ? this.render() : this.close();
  }

  render() {
    this.el.innerHTML = this.items.map((item, i) => `
      <div class="forum-mention-item${i === this.active ? " is-active" : ""}"
           role="option" data-index="${i}" aria-selected="${i === this.active}">
        <span class="forum-mention-label"></span>
        <span class="forum-mention-sub"></span>
      </div>`).join("");
    // Set text as textContent so a survivor or episode title cannot inject markup.
    this.el.querySelectorAll("[data-index]").forEach((row, i) => {
      row.querySelector(".forum-mention-label").textContent = this.items[i].label;
      row.querySelector(".forum-mention-sub").textContent = this.items[i].sub || "";
    });

    const { x, y } = caretPoint(this.textarea);
    this.el.style.left = `${Math.round(x)}px`;
    this.el.style.top = `${Math.round(y)}px`;
    this.el.hidden = false;
  }

  onKeydown(event) {
    if (this.el.hidden) return;
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const step = event.key === "ArrowDown" ? 1 : -1;
      this.active = (this.active + step + this.items.length) % this.items.length;
      this.render();
    } else if (event.key === "Enter" || event.key === "Tab") {
      event.preventDefault();
      this.choose(this.active);
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.close();
    }
  }

  choose(index) {
    const item = this.items[index];
    if (!item || !this.token) return this.close();

    const area = this.textarea;
    const prefix = area.value.slice(0, this.token.start);
    const suffix = area.value.slice(area.selectionStart);
    const markdown = `[${this.token.char}${item.label}](${item.path})`;

    area.value = `${prefix}${markdown} ${suffix}`;
    const caret = prefix.length + markdown.length + 1;
    area.setSelectionRange(caret, caret);
    area.focus();
    area.dispatchEvent(new Event("input", { bubbles: true }));
    this.close();
  }

  close() {
    this.el.hidden = true;
    this.items = [];
    this.token = null;
  }
}

function attachMentions() {
  document.querySelectorAll("textarea[data-mentions]").forEach((area) => {
    if (area.dataset.mentionsReady) return;
    area.dataset.mentionsReady = "1";
    new MentionMenu(area);
  });
}

document.addEventListener("turbo:load", attachMentions);
document.addEventListener("DOMContentLoaded", attachMentions);
export {};
