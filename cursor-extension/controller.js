import { CSS, TOP, TOP_PATTERN, matchesUrl, isMoonlightProof, chooseDocument } from './policy.js';
import { readTopProof, readCanvasProof, watchTop } from './probes.js';

export function createController(api, settings) {
  let queue = Promise.resolve();
  const key = entry => `${entry.tabId}:${entry.documentId}`;

  async function topProof(tabId) {
    const results = await api.scripting.executeScript({ target: { tabId, frameIds: [0] },
      func: readTopProof, args: [settings] });
    return results.length === 1 && isMoonlightProof(results[0].result, settings);
  }

  async function audit() {
    const stored = await api.storage.session.get(['enabled', 'applied']);
    const enabled = stored.enabled !== false;
    const old = Array.isArray(stored.applied) ? stored.applied : [];
    const owners = [];
    const tabs = await api.tabs.query({ url: TOP_PATTERN });
    let uncertain = false;
    for (const tab of tabs) {
      if (!matchesUrl(tab.url, TOP)) continue;
      try {
        // Top frame only. An isolated watcher notices Demado's delayed initialization.
        await api.scripting.executeScript({ target: { tabId: tab.id, frameIds: [0] }, func: watchTop, args: [settings] });
        if (!await topProof(tab.id)) continue;
        const peers = await api.tabs.query({ windowId: tab.windowId });
        if (peers.length !== 1) { uncertain = true; continue; }
        owners.push(tab);
      } catch { uncertain = true; }
    }

    let wanted = null;
    let status = !enabled ? 'paused' : uncertain || owners.length > 1 ? 'ambiguous' : 'waiting';
    if (enabled && !uncertain && owners.length === 1) {
      const tab = owners[0];
      try {
        const win = await api.windows.get(tab.windowId);
        if (win.state === 'fullscreen') {
          const target = chooseDocument(await api.webNavigation.getAllFrames({ tabId: tab.id }));
          if (target) {
            const result = await api.scripting.executeScript({ target: { tabId: tab.id, documentIds: [target.documentId] }, func: readCanvasProof });
            if (result.length === 1 && result[0].result === true && await topProof(tab.id)) {
              // Recheck fullscreen immediately before deciding to insert.
              const now = await api.windows.get(tab.windowId);
              if (now.state === 'fullscreen') wanted = { tabId: tab.id, documentId: target.documentId };
            }
          }
        }
      } catch { status = 'unavailable'; }
    }

    const retained = [];
    for (const entry of old) {
      if (wanted && key(entry) === key(wanted) && !entry.pending) { retained.push(entry); continue; }
      try {
        await api.scripting.removeCSS({ target: { tabId: entry.tabId, documentIds: [entry.documentId] }, css: CSS, origin: 'USER' });
      } catch {
        // Gone documents have no CSS left. A live, inaccessible document must be retried.
        let alive = true;
        try { const frames = await api.webNavigation.getAllFrames({ tabId: entry.tabId }); alive = frames?.some(f => f.documentId === entry.documentId) ?? true; }
        catch { try { await api.tabs.get(entry.tabId); } catch { alive = false; } }
        if (alive) { retained.push(entry); status = 'cleanup-pending'; }
      }
    }
    // Never add CSS to a new document while cleanup of another is incomplete.
    if (wanted && !retained.some(e => key(e) === key(wanted)) && retained.length === 0) {
      // Persist the intended target first so a worker suspension after insert is recoverable.
      const currentTab = await api.tabs.get(wanted.tabId);
      const peers = await api.tabs.query({ windowId: currentTab.windowId });
      const currentWindow = await api.windows.get(currentTab.windowId);
      const currentDocument = chooseDocument(await api.webNavigation.getAllFrames({ tabId: wanted.tabId }));
      if (peers.length !== 1 || currentWindow.state !== 'fullscreen' ||
          currentDocument?.documentId !== wanted.documentId || !await topProof(wanted.tabId)) {
        await api.storage.session.set({ applied: retained, status: 'waiting' });
        return { status: 'waiting', appliedCount: retained.length };
      }
      await api.storage.session.set({ applied: [{ ...wanted, pending: true }] });
      try {
        await api.scripting.insertCSS({ target: { tabId: wanted.tabId, documentIds: [wanted.documentId] }, css: CSS, origin: 'USER' });
        retained.push(wanted);
      } catch { retained.push({ ...wanted, pending: true }); status = 'unavailable'; }
    }
    if (wanted && retained.some(e => key(e) === key(wanted) && !e.pending) && status === 'waiting') status = 'active';
    await api.storage.session.set({ applied: retained, status });
    return { status, appliedCount: retained.length };
  }

  function schedule() {
    const run = queue.then(audit);
    queue = run.catch(() => {});
    return run;
  }
  async function toggle() {
    const state = await api.storage.session.get('enabled');
    await api.storage.session.set({ enabled: state.enabled === false });
    return schedule();
  }
  return { schedule, toggle };
}
