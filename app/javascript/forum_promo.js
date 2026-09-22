// Dismissing the forum banner. The server decides whether to render it by
// reading this cookie, so a returning reader never sees it appear and then
// vanish — which is what a JS-only hide would do.

function dismiss(event) {
  const banner = event.target.closest(".forum-promo");
  if (!banner) return;
  const oneYear = 60 * 60 * 24 * 365;
  document.cookie = `forum_promo_dismissed=1; path=/; max-age=${oneYear}; samesite=lax`;
  banner.remove();
}

function attachPromo() {
  document.querySelectorAll(".forum-promo-close").forEach((btn) => {
    if (btn.dataset.promoReady) return;
    btn.dataset.promoReady = "1";
    btn.addEventListener("click", dismiss);
  });
}

document.addEventListener("turbo:load", attachPromo);
document.addEventListener("DOMContentLoaded", attachPromo);
export {};
