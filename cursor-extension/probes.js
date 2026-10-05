// These functions are serialized by chrome.scripting. Keep them self-contained.
// Only Demado's two named settings keys are read; never enumerate storage.
export function readTopProof(settings) {
  try {
    if (location.origin !== 'https://play.games.dmm.co.jp' || location.pathname !== '/game/pjivn_293854') return null;
    const prefix = `demado_${settings.demadoExtensionId}_`;
    const markerId = sessionStorage.getItem(prefix + 'id');
    if (markerId !== settings.cardId) return null;
    const card = JSON.parse(sessionStorage.getItem(prefix + 'madojson') || 'null');
    if (!card || card.name !== settings.cardName) return null;
    const cardUrl = new URL(card.url);
    if (cardUrl.origin !== location.origin || cardUrl.pathname !== location.pathname) return null;
    const frames = document.querySelectorAll('iframe#game_frame');
    if (frames.length !== 1) return null;
    const outer = new URL(frames[0].src, location.href);
    return { markerId, cardName: card.name, cardUrl: cardUrl.origin + cardUrl.pathname,
      topOrigin: location.origin, topPath: location.pathname, outerCount: frames.length,
      outerOrigin: outer.origin, outerPath: outer.pathname };
  } catch { return null; }
}

export function readCanvasProof() {
  // Do not expose query parameters, game variables, network data or page text.
  return location.origin === 'https://iv-n-tight.saikyo.biz' && location.pathname === '/app_data/' &&
    document.querySelectorAll('canvas#unity-canvas').length === 1;
}

export function watchTop(settings) {
  const key = '__pjivnCursorWatch_' + chrome.runtime.id;
  if (globalThis[key]) return;
  globalThis[key] = true;
  let previous;
  const timer = setInterval(() => {
    let signature;
    try {
      const prefix = `demado_${settings.demadoExtensionId}_`;
      const marker = sessionStorage.getItem(prefix + 'id');
      let name = '', url = '';
      if (marker === settings.cardId) {
        const card = JSON.parse(sessionStorage.getItem(prefix + 'madojson') || 'null');
        name = card?.name || '';
        if (card?.url) { const u = new URL(card.url); url = u.origin + u.pathname; }
      }
      const frame = document.querySelectorAll('iframe#game_frame');
      let outer = '';
      if (frame.length === 1) { const u = new URL(frame[0].src, location.href); outer = u.origin + u.pathname; }
      // Local signature only: no storage or URL values are sent to the worker.
      signature = JSON.stringify([marker === settings.cardId, name === settings.cardName,
        url === 'https://play.games.dmm.co.jp/game/pjivn_293854', frame.length, outer]);
      if (signature !== previous) {
        previous = signature;
        chrome.runtime.sendMessage({ type: 'cursor-proof-changed' }).catch(() => { clearInterval(timer); });
      }
    } catch { signature = 'invalid'; }
    if (signature === 'invalid' && previous !== signature) {
      previous = signature;
      try { chrome.runtime.sendMessage({ type: 'cursor-proof-changed' }).catch(() => { clearInterval(timer); }); }
      catch { clearInterval(timer); }
    }
  }, 1000);
}
