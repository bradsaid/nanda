// Hooks up the footer "Manage privacy preferences" link to Google Funding
// Choices so visitors can re-open the consent dialog after their first visit.
document.addEventListener("click", function(e) {
  const trigger = e.target.closest('[data-action="manage-privacy"]');
  if (!trigger) return;
  e.preventDefault();

  // Funding Choices exposes window.googlefc once its script has loaded. The
  // callbackQueue lets us defer the call until the CMP is ready.
  if (!window.googlefc) {
    alert("The privacy preferences panel is still loading. Please try again in a moment.");
    return;
  }
  window.googlefc.callbackQueue = window.googlefc.callbackQueue || [];
  window.googlefc.callbackQueue.push({
    'CONSENT_DATA_READY': function() {
      window.googlefc.showRevocationMessage();
    }
  });
});
