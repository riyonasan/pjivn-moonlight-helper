import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { CSS, TOP, chooseDocument } from '../linux-extension/policy.js';
import { createController } from '../linux-extension/controller.js';

function frames(doc = 'game-doc') {
  return [{ frameId: 0, parentFrameId: -1, documentId: 'top', url: TOP.origin + TOP.path },
    { frameId: 2, parentFrameId: 0, documentId: 'outer', url: 'https://osapi.dmm.com/gadgets/ifr?DO_NOT_RETURN=token' },
    { frameId: 3, parentFrameId: 2, documentId: doc, url: 'https://iv-n-tight.saikyo.biz/app_data/?session_id=DO_NOT_RETURN' },
    { frameId: 4, parentFrameId: 2, documentId: 'news', url: 'https://iv-n-tight.saikyo.biz/gadget_news' }];
}
function mock() {
  const state = { tabs: [{ id: 10, windowId: 100, url: TOP.origin + TOP.path }], 
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
      insertCSS: async args => { state.inserted.push(args); if (state.insertFails) throw Error('permission denied'); },
      removeCSS: async args => { state.removed.push(args); if (state.removeFails) throw Error('permission denied'); }
    }
  };
  return { state, api, controller: createController(api) };
}


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

test('reload/iframe regeneration targets the new document; CSS does not reach news', async () => {
  const { state, controller } = mock(); await controller.schedule(); state.frames.set(10, frames('replacement'));
  await controller.schedule(); assert.equal(state.removed[0].target.documentIds[0], 'game-doc');
  assert.equal(state.inserted[1].target.documentIds[0], 'replacement');
});

test('closed tab clears stale records and worker restart preserves cleanup', async () => {
  const { state, api, controller } = mock(); await controller.schedule();
  state.windows.set(100, { state: 'normal' });
  await createController(api).schedule();
  assert.equal(state.removed.length, 1, 'new worker must recover applied document from session storage');
  state.windows.set(100, { state: 'fullscreen' }); await controller.schedule();
  state.tabs = []; state.frames.clear(); state.removeFails = true;
  await controller.schedule(); assert.deepEqual(state.storage.applied, []);
});

test('failed insert retries instead of falsely reporting active; failed cleanup blocks new injection', async () => {
  const { state, controller } = mock(); state.insertFails = true;
  assert.equal((await controller.schedule()).status, 'unavailable'); assert.equal(state.storage.applied[0].pending, true);
  state.insertFails = false; state.removeFails = true;
  assert.equal((await controller.schedule()).status, 'cleanup-pending'); assert.equal(state.inserted.length, 1, 'unconfirmed CSS cannot be reported active or duplicated');
  state.removeFails = false; assert.equal((await controller.schedule()).status, 'active'); assert.equal(state.inserted.length, 2);
  state.windows.set(100, { state: 'normal' }); state.removeFails = true;
  assert.equal((await controller.schedule()).status, 'cleanup-pending'); assert.equal(state.storage.applied.length, 1);
});

test('fullscreen applies once, normal window and pause restore cursor', async () => {
  const {state, controller} = mock();
  state.windows.set(100, {state:'normal'});
  await controller.schedule(); assert.equal(state.inserted.length,0);
  state.windows.set(100, {state:'fullscreen'});
  await controller.schedule(); await controller.schedule();
  assert.deepEqual(state.inserted,[{target:{tabId:10,documentIds:['game-doc']},css:CSS,origin:'USER'}]);
  state.windows.set(100, {state:'normal'});
  await controller.schedule(); assert.deepEqual(state.removed,state.inserted);
  state.windows.set(100, {state:'fullscreen'}); await controller.schedule();
  await controller.toggle(); assert.equal(state.storage.status,'paused'); assert.equal(state.storage.applied.length,0);
  await controller.toggle(); assert.equal(state.storage.status,'active');
});
test('duplicate game, multiple tabs and unrelated URL never hide cursor', async () => {
  for (const alter of [
    s=>s.tabs.push({id:20,windowId:200,url:TOP.origin+TOP.path}),
    s=>s.tabs.push({id:11,windowId:100,url:'https://other.invalid'}),
    s=>{s.tabs[0].url+='other';},
    s=>{s.frames.get(10)[2].parentFrameId=0;}
  ]) { const {state,controller}=mock(); alter(state); await controller.schedule(); assert.equal(state.inserted.length,0); }
});
test('navigation and fullscreen changes during audit prevent insertion', async () => {
  for (const change of ['url','window']) {
    const {state,api,controller}=mock(); let reads=0;
    const original=api.windows.get;
    api.windows.get=async id=>{
      if (++reads===2) {
        if(change==='url') state.tabs[0].url='https://other.invalid';
        else state.windows.set(100,{state:'normal'});
      }
      return original(id);
    };
    await controller.schedule(); assert.equal(state.inserted.length,0);
  }
});

test('packaged worker handles fullscreen, navigation, restart and pause events', async () => {
  const listeners=new Map(); const event=name=>({addListener:fn=>listeners.set(name,fn)});
  let audits=0,toggles=0;
  const context={createController:()=>({schedule:async()=>{audits++;return {status:'waiting'};},toggle:async()=>{toggles++;return {status:'paused'};}}),
    chrome:{runtime:{onInstalled:event('installed'),onStartup:event('startup')},
      action:{onClicked:event('click'),setBadgeText:async()=>{},setTitle:async()=>{}},
      tabs:Object.fromEntries(['onUpdated','onRemoved','onCreated','onReplaced','onAttached','onDetached'].map(n=>[n,event(n)])),
      windows:{onBoundsChanged:event('bounds')},
      webNavigation:Object.fromEntries(['onCommitted','onDOMContentLoaded','onCompleted','onHistoryStateUpdated'].map(n=>[n,event(n)])),
      alarms:{onAlarm:event('alarm'),create:async()=>{}}}};
  const root=new URL('../linux-extension/',import.meta.url);
  const source=fs.readFileSync(new URL('background.js',root),'utf8').replace(/^import .*;\r?\n/gm,'');
  vm.runInNewContext(source,context); await new Promise(r=>setImmediate(r)); assert.equal(audits,1);
  for(const name of ['installed','startup','bounds','onCommitted','onDOMContentLoaded','onCompleted','onHistoryStateUpdated','onRemoved','onCreated','onReplaced','onAttached','onDetached']) listeners.get(name)();
  listeners.get('onUpdated')(10,{status:'complete'}); listeners.get('alarm')({name:'cursor-audit'});
  listeners.get('click')(); await new Promise(r=>setImmediate(r)); assert.equal(audits,15); assert.equal(toggles,1);
  const manifest=JSON.parse(fs.readFileSync(new URL('manifest.json',root)));
  assert.deepEqual(manifest.host_permissions,['https://play.games.dmm.co.jp/*','https://iv-n-tight.saikyo.biz/*']);
  assert.equal(manifest.background.service_worker,'background.js'); assert.equal(manifest.background.type,'module');
  for(const name of ['background.js','controller.js','policy.js']) assert.doesNotMatch(fs.readFileSync(new URL(name,root),'utf8'),/executeScript|fetch\(|document\.cookie|storage\.sync|permissions\.request/);
});
