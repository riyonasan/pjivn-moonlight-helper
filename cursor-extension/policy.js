export const TOP = { origin: 'https://play.games.dmm.co.jp', path: '/game/pjivn_293854' };
export const OUTER = { origin: 'https://osapi.dmm.com', path: '/gadgets/ifr' };
export const INNER = { origin: 'https://iv-n-tight.saikyo.biz', path: '/app_data/' };
export const CSS = '#unity-canvas { cursor: none !important; }';
export const TOP_PATTERN = 'https://play.games.dmm.co.jp/game/pjivn_293854*';

export function matchesUrl(value, endpoint) {
  try {
    const u = new URL(value);
    return u.origin === endpoint.origin && u.pathname === endpoint.path;
  } catch { return false; }
}

export function validateSettings(value) {
  if (!value || value.schemaVersion !== 1 || value.usage !== 'moonlight' ||
      !/^[a-p]{32}$/.test(value.demadoExtensionId) ||
      typeof value.cardId !== 'string' || !/^[a-z0-9]+$/.test(value.cardId) || value.cardId === 'REPLACE_AFTER_IMPORT' ||
      typeof value.cardName !== 'string' || !value.cardName.includes('Moonlight') ||
      value.cardName.length > 200 || /[\r\n]/.test(value.cardName) ||
      value.requireFullscreen !== true) {
    throw new Error('Invalid Moonlight cursor settings. Generate the package from a verified Moonlight config.');
  }
  // Return only the non-secret fields the extension actually needs.
  return { schemaVersion: 1, usage: 'moonlight', demadoExtensionId: value.demadoExtensionId,
    cardId: value.cardId, cardName: value.cardName, requireFullscreen: true };
}

export function isMoonlightProof(proof, settings) {
  return !!proof && proof.markerId === settings.cardId && proof.cardName === settings.cardName &&
    matchesUrl(proof.cardUrl, TOP) && proof.topOrigin === TOP.origin && proof.topPath === TOP.path &&
    proof.outerCount === 1 && proof.outerOrigin === OUTER.origin && proof.outerPath === OUTER.path;
}

export function chooseDocument(frames) {
  if (!Array.isArray(frames)) return null;
  const root = frames.filter(f => f.frameId === 0 && matchesUrl(f.url, TOP));
  if (root.length !== 1) return null;
  const outer = frames.filter(f => f.parentFrameId === 0 && matchesUrl(f.url, OUTER));
  if (outer.length !== 1) return null;
  const inner = frames.filter(f => f.parentFrameId === outer[0].frameId && matchesUrl(f.url, INNER));
  if (inner.length !== 1 || typeof inner[0].documentId !== 'string' || !inner[0].documentId) return null;
  const f = inner[0];
  return { documentId: f.documentId, frameId: f.frameId };
}
