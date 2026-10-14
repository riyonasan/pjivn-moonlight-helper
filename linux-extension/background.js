import { createController } from './controller.js';
const ready = Promise.resolve(createController(chrome));

async function run(toggle = false) {
  try {
    const controller = await ready;
    const result = await (toggle ? controller.toggle() : controller.schedule());
    await chrome.action.setBadgeText({ text: result.status === 'active' ? 'ON' : result.status === 'paused' ? 'OFF' : result.status === 'waiting' ? '' : '?' });
    await chrome.action.setTitle({ title: 'Moonlight cursor: ' + result.status + '. Click to pause/resume.' });
  } catch {
    await chrome.action.setBadgeText({ text: 'ERR' });
    await chrome.action.setTitle({ title: 'Moonlight cursor unavailable. Check extension site permissions; no permission is requested automatically.' });
  }
}

chrome.action.onClicked.addListener(() => { void run(true); });
chrome.runtime.onInstalled.addListener(() => { void run(); });
chrome.runtime.onStartup.addListener(() => { void run(); });
const filter = { url: [{ hostEquals: 'play.games.dmm.co.jp' }, { hostEquals: 'osapi.dmm.com' }, { hostEquals: 'iv-n-tight.saikyo.biz' }] };
for (const event of [chrome.webNavigation.onCommitted, chrome.webNavigation.onDOMContentLoaded,
  chrome.webNavigation.onCompleted, chrome.webNavigation.onHistoryStateUpdated]) event.addListener(() => { void run(); }, filter);
chrome.tabs.onUpdated.addListener((_id, info) => { if (info.url || info.status) void run(); });
chrome.tabs.onRemoved.addListener(() => { void run(); });
chrome.tabs.onCreated.addListener(() => { void run(); });
chrome.tabs.onReplaced.addListener(() => { void run(); });
chrome.tabs.onAttached.addListener(() => { void run(); });
chrome.tabs.onDetached.addListener(() => { void run(); });
chrome.windows.onBoundsChanged.addListener(() => { void run(); });
chrome.alarms.onAlarm.addListener(alarm => { if (alarm.name === 'cursor-audit') void run(); });
void chrome.alarms.create('cursor-audit', { periodInMinutes: 1 });
void run();
