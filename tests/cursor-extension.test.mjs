import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { CSS, TOP, TOP_PATTERN, validateSettings, isMoonlightProof, chooseDocument } from '../cursor-extension/policy.js';
import { createController } from '../cursor-extension/controller.js';
import { readTopProof, readCanvasProof, watchTop } from '../cursor-extension/probes.js';

const settings = { schemaVersion: 1, usage: 'moonlight', demadoExtensionId: 'dfmhlfpfpbijchleocfbpcdjgnbpdigh', cardId: 'moon123', cardName: 'イヴンタイト(Moonlight)', requireFullscreen: true };
const proof = { markerId: settings.cardId, cardName: settings.cardName, cardUrl: TOP.origin + TOP.path,
  topOrigin: TOP.origin, topPath: TOP.path, outerCount: 1, outerOrigin: 'https://osapi.dmm.com', outerPath: '/gadgets/ifr' };
function frames(doc = 'game-doc') {
  return [{ frameId: 0, parentFrameId: -1, documentId: 'top', url: TOP.origin + TOP.path },
    { frameId: 2, parentFrameId: 0, documentId: 'outer', url: 'https://osapi.dmm.com/gadgets/ifr?DO_NOT_RETURN=token' },
    { frameId: 3, parentFrameId: 2, documentId: doc, url: 'https://iv-n-tight.saikyo.biz/app_data/?session_id=DO_NOT_RETURN' },
    { frameId: 4, parentFrameId: 2, documentId: 'news', url: 'https://iv-n-tight.saikyo.biz/gadget_news' }];
}
function mock() {
  const state = { tabs: [{ id: 10, windowId: 100, url: TOP.origin + TOP.path }], proofs: new Map([[10, structuredClone(proof)]]),
    frames: new Map([[10, frames()]]), windows: new Map([[100, { state: 'fullscreen' }]]),
    storage: {}, inserted: [], removed: [], canRead: true, canvas: true, insertFails: false, removeFails: false };
  const api = {
    tabs: {
      query: async q => state.tabs.filter(t => q.windowId !== undefined ? t.windowId === q.windowId : t.url.startsWith(TOP.origin + TOP.path)),
      get: async id => { const tab = state.tabs.find(t => t.id === id); if (!tab) throw Error('closed'); return tab; }
    },
    windows: { get: async id => state.windows.get(id) },
    webNavigation: { getAllFrames: async ({ tabId }) => { if (!state.frames.has(tabId)) throw Error('closed'); return state.frames.get(tabId); } },
    storage: { session: {
      get: async keys => Object.fromEntries((Array.isArray(keys) ? keys : [keys]).map(k => [k, state.storage[k]])),
      set: async value => Object.assign(state.storage, structuredClone(value))
    } },
    scripting: {
      executeScript: async args => {
        assert.equal(args.target.allFrames, undefined);
        if (!state.canRead) throw Error('permission denied');
        if (args.func === watchTop) return [{ result: undefined }];
        if (args.func === readTopProof) return [{ result: state.proofs.get(args.target.tabId) ?? null }];
        if (args.func === readCanvasProof) return [{ result: state.canvas }];
        throw Error('unexpected script');
      },
      insertCSS: async args => { state.inserted.push(args); if (state.insertFails) throw Error('permission denied'); },
      removeCSS: async args => { state.removed.push(args); if (state.removeFails) throw Error('permission denied'); }
    }
  };
  return { state, api, controller: createController(api, validateSettings(settings)) };
}

test('configuration fails closed and drops unrelated fields', () => {
  assert.deepEqual(validateSettings({ ...settings, ChromePath: 'private', token: 'not-exported' }), settings);
  for (const value of [{ ...settings, usage: 'pc' }, { ...settings, cardId: undefined }, { ...settings, cardId: 'REPLACE_AFTER_IMPORT' }, { ...settings, cardName: 'PC' }, { ...settings, requireFullscreen: false }, { ...settings, demadoExtensionId: 'invalid' }]) assert.throws(() => validateSettings(value));
});

test('card ID, name and outer iframe are required; URL alone never authorizes', () => {
  assert.equal(isMoonlightProof(proof, settings), true);
  for (const invalid of [null, { ...proof, markerId: 'pc123' }, { ...proof, cardName: 'PC' }, { ...proof, outerCount: 2 }, { ...proof, outerOrigin: 'https://wrong.invalid' }]) assert.equal(isMoonlightProof(invalid, settings), false);
});

test('exact two-level ancestry, origin/path and document ID exclude news/unrelated frames', () => {
  assert.deepEqual(chooseDocument(frames()), { frameId: 3, documentId: 'game-doc' });
  const wrongParent = frames(); wrongParent[2].parentFrameId = 0;
  assert.equal(chooseDocument(wrongParent), null);
  const duplicate = frames(); duplicate.push({ ...duplicate[2], frameId: 5 });
  assert.equal(chooseDocument(duplicate), null);
  const missingDoc = frames(); delete missingDoc[2].documentId;
  assert.equal(chooseDocument(missingDoc), null);
  const changedPath = frames(); changedPath[2].url = 'https://iv-n-tight.saikyo.biz/app_data/other';
  assert.equal(chooseDocument(changedPath), null);
});

test('only verified fullscreen Moonlight receives CSS; same-name PC in F11 fullscreen stays unchanged', async () => {
  const { state, controller } = mock();
  state.tabs.push({ id: 20, windowId: 200, url: TOP.origin + TOP.path });
  state.proofs.set(20, { ...proof, markerId: 'pc456', cardName: settings.cardName });
  state.windows.set(200, { state: 'fullscreen' });
  assert.equal((await controller.schedule()).status, 'active');
  assert.deepEqual(state.inserted, [{ target: { tabId: 10, documentIds: ['game-doc'] }, css: CSS, origin: 'USER' }]);
  assert.deepEqual(state.removed, []);
  await controller.schedule();
  assert.equal(state.inserted.length, 1, 'repeated audit must not duplicate CSS');
});

test('normal window / multi-tab window / absent canvas / denied read get no CSS', async () => {
  for (const alter of [s => s.windows.set(100, { state: 'normal' }), s => s.tabs.push({ id: 11, windowId: 100, url: 'https://other.invalid' }), s => { s.canvas = false; }, s => { s.canRead = false; }]) {
    const { state, controller } = mock(); alter(state); await controller.schedule(); assert.equal(state.inserted.length, 0);
  }
});

test('duplicate Moonlight card identities remove existing CSS and refuse both', async () => {
  const { state, controller } = mock(); await controller.schedule();
  state.tabs.push({ id: 20, windowId: 200, url: TOP.origin + TOP.path }); state.proofs.set(20, proof);
  assert.equal((await controller.schedule()).status, 'ambiguous');
  assert.equal(state.removed.length, 1); assert.equal(state.storage.applied.length, 0);
});

test('fullscreen exit, card identity loss and pause remove only our CSS', async () => {
  for (const reason of ['fullscreen', 'identity', 'pause']) {
    const { state, controller } = mock(); await controller.schedule();
    if (reason === 'fullscreen') state.windows.set(100, { state: 'normal' });
    if (reason === 'identity') state.proofs.set(10, null);
    await (reason === 'pause' ? controller.toggle() : controller.schedule());
    assert.deepEqual(state.removed, state.inserted); assert.deepEqual(state.storage.applied, []);
  }
});

test('reload/iframe regeneration targets the new document; CSS does not reach news', async () => {
  const { state, controller } = mock(); await controller.schedule(); state.frames.set(10, frames('replacement'));
  await controller.schedule(); assert.equal(state.removed[0].target.documentIds[0], 'game-doc');
  assert.equal(state.inserted[1].target.documentIds[0], 'replacement');
});

test('closed tab clears stale records and worker restart preserves cleanup', async () => {
  const { state, api, controller } = mock(); await controller.schedule();
  state.windows.set(100, { state: 'normal' });
  await createController(api, settings).schedule();
  assert.equal(state.removed.length, 1, 'new worker must recover applied document from session storage');
  state.windows.set(100, { state: 'fullscreen' }); await controller.schedule();
  state.tabs = []; state.frames.clear(); state.removeFails = true;
  await controller.schedule(); assert.deepEqual(state.storage.applied, []);
});

test('top-frame watcher notices delayed card init, identity loss and stops on extension unload', async () => {
  let marker = null, card = null, tick, messages = 0, cleared = false;
  const context = { URL, settings,
    chrome: { runtime: { id: 'helper-extension', sendMessage: async message => {
      assert.deepEqual(Object.keys(message), ['type']); messages++;
    } } },
    sessionStorage: { getItem: key => key.endsWith('_madojson') ? card : marker },
    document: { querySelectorAll: () => [{ src: 'https://osapi.dmm.com/gadgets/ifr?token=never-sent' }] },
    location: { href: TOP.origin + TOP.path },
    setInterval: fn => { tick = fn; return 1; }, clearInterval: () => { cleared = true; }
  };
  vm.runInNewContext(`(${watchTop.toString()})(settings)`, context);
  tick(); await Promise.resolve(); assert.equal(messages, 1);
  marker = settings.cardId; card = JSON.stringify({ name: settings.cardName, url: TOP.origin + TOP.path });
  tick(); await Promise.resolve(); assert.equal(messages, 2);
  tick(); assert.equal(messages, 2, 'stable proof must not send repeated messages');
  marker = 'pc-card'; tick(); await Promise.resolve(); assert.equal(messages, 3);
  context.chrome.runtime.sendMessage = () => { throw Error('extension unloaded'); };
  marker = settings.cardId; tick(); assert.equal(cleared, true);
});

test('failed insert retries instead of falsely reporting active; failed cleanup blocks new injection', async () => {
  const { state, controller } = mock(); state.insertFails = true;
  assert.equal((await controller.schedule()).status, 'unavailable'); assert.equal(state.storage.applied[0].pending, true);
  state.insertFails = false; state.removeFails = true;
  assert.equal((await controller.schedule()).status, 'cleanup-pending'); assert.equal(state.inserted.length, 1, 'unconfirmed CSS cannot be reported active or duplicated');
  state.removeFails = false; assert.equal((await controller.schedule()).status, 'active'); assert.equal(state.inserted.length, 2);
  state.proofs.set(10, null); state.removeFails = true;
  assert.equal((await controller.schedule()).status, 'cleanup-pending'); assert.equal(state.storage.applied.length, 1);
});

test('the real serialized top probe reads only named Demado keys and never returns auth queries', () => {
  const seen = [];
  const ctx = {
    URL, location: { origin: TOP.origin, pathname: TOP.path, href: TOP.origin + TOP.path },
    sessionStorage: { getItem: key => {
      seen.push(key);
      if (key.endsWith('_id')) return settings.cardId;
      if (key.endsWith('_madojson')) return JSON.stringify({ name: settings.cardName, url: TOP.origin + TOP.path, token: 'DO_NOT_RETURN' });
      throw Error('unexpected storage read');
    } },
    document: { querySelectorAll: selector => { assert.equal(selector, 'iframe#game_frame'); return [{ src: 'https://osapi.dmm.com/gadgets/ifr?st=DO_NOT_RETURN' }]; } }
  };
  const result = vm.runInNewContext(`(${readTopProof.toString()})(settings)`, { ...ctx, settings });
  assert.equal(isMoonlightProof(result, settings), true);
  assert.equal(JSON.stringify(result).includes('DO_NOT_RETURN'), false);
  assert.deepEqual(seen, [`demado_${settings.demadoExtensionId}_id`, `demado_${settings.demadoExtensionId}_madojson`]);
});

test('manifest is narrow, dependency-free, without blanket frame CSS or permission requests', () => {
  const root = new URL('../cursor-extension/', import.meta.url);
  const manifest = JSON.parse(fs.readFileSync(new URL('manifest.json', root)));
  assert.deepEqual(manifest.host_permissions, ['https://play.games.dmm.co.jp/*', 'https://iv-n-tight.saikyo.biz/*']);
  assert.deepEqual(manifest.permissions, ['scripting', 'webNavigation', 'storage', 'alarms']);
  assert.equal(manifest.content_scripts, undefined);
  assert.equal(manifest.externally_connectable, undefined);
  for (const name of ['background.js', 'controller.js', 'policy.js', 'probes.js']) {
    const text = fs.readFileSync(new URL(name, root), 'utf8');
    assert.doesNotMatch(text, /allFrames\s*:\s*true|permissions\.request|storage\.sync|document\.cookie|nativeMessaging|<all_urls>/);
  }
  assert.equal(CSS, '#unity-canvas { cursor: none !important; }');
  const cssFile = fs.readFileSync(new URL('../demado/pjivn-moonlight-frame-cursor.css', root), 'utf8').trim();
  assert.equal(CSS, cssFile, 'Git cursor CSS and extension must stay synchronized');
  assert.equal(TOP_PATTERN, 'https://play.games.dmm.co.jp/game/pjivn_293854*');
});

test('worker wires lifecycle audits, acknowledges own top notifier, and rejects foreign/frame messages', async () => {
  const listeners = new Map();
  const event = name => ({ addListener: fn => listeners.set(name, fn) });
  let audits = 0, toggles = 0, replies = 0;
  const context = {
    validateSettings,
    createController: () => ({ schedule: async () => { audits++; return { status: 'waiting' }; }, toggle: async () => { toggles++; return { status: 'paused' }; } }),
    fetch: async url => { assert.equal(url, 'chrome-extension://helper/settings.local.json'); return { ok: true, json: async () => settings }; },
    chrome: {
      runtime: { id: 'helper', getURL: name => 'chrome-extension://helper/' + name,
        onInstalled: event('installed'), onStartup: event('startup'), onMessage: event('message') },
      action: { onClicked: event('click'), setBadgeText: async () => {}, setTitle: async () => {} },
      tabs: Object.fromEntries(['onUpdated', 'onRemoved', 'onCreated', 'onReplaced', 'onAttached', 'onDetached'].map(n => [n, event(n)])),
      windows: { onBoundsChanged: event('bounds') },
      webNavigation: Object.fromEntries(['onCommitted', 'onDOMContentLoaded', 'onCompleted', 'onHistoryStateUpdated'].map(n => [n, event(n)])),
      alarms: { onAlarm: event('alarm'), create: async (_name, opts) => { assert.equal(opts.periodInMinutes, 1); } }
    }
  };
  const source = fs.readFileSync(new URL('../cursor-extension/background.js', import.meta.url), 'utf8').replace(/^import .*;\r?\n/gm, '');
  vm.runInNewContext(source, context);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(audits, 1);
  listeners.get('message')({ type: 'cursor-proof-changed' }, { id: 'other', frameId: 0 }, () => { replies++; });
  listeners.get('message')({ type: 'cursor-proof-changed' }, { id: 'helper', frameId: 2 }, () => { replies++; });
  await new Promise(resolve => setImmediate(resolve)); assert.equal(audits, 1); assert.equal(replies, 0);
  listeners.get('message')({ type: 'cursor-proof-changed' }, { id: 'helper', frameId: 0 }, () => { replies++; });
  await new Promise(resolve => setImmediate(resolve)); assert.equal(audits, 2); assert.equal(replies, 1);
  listeners.get('click')(); await new Promise(resolve => setImmediate(resolve)); assert.equal(toggles, 1);
  for (const name of ['installed', 'startup', 'onCommitted', 'onDOMContentLoaded', 'onCompleted', 'onHistoryStateUpdated', 'bounds', 'onRemoved', 'onReplaced']) assert.equal(typeof listeners.get(name), 'function');
});

test('base launcher remains independent of optional extension/package/settings', () => {
  for (const name of ['launch-pjivn.ps1', 'fullscreen-pjivn.ps1', 'helper-common.ps1']) {
    const source = fs.readFileSync(new URL('../' + name, import.meta.url), 'utf8');
    assert.doesNotMatch(source, /cursor-extension|config\.cursor|prepare-cursor-extension|Read-CursorIdentityConfig/);
  }
  const generator = fs.readFileSync(new URL('../prepare-cursor-extension.ps1', import.meta.url), 'utf8');
  assert.match(generator, /config\.cursor\.local\.json/);
  assert.doesNotMatch(generator, /\$config=Read-HelperConfig/);
});
