import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../web/portrait_shell.html', import.meta.url), 'utf8')
  .match(/\/\/ A small host API[\s\S]*?<\/script>/)[0].replace(/<\/script>$/, '');
const calls = [], listeners = new Map();
let subscriber, saved, offline = false, paused = 0, resumed = 0;
let legacyServer = false;
let catalogEnabled = false, orderStarted = false, owned = false, entitlementReads = 0;
const context = {
  console, URL, URLSearchParams, AbortController,
  setTimeout: (callback, ms) => setTimeout(callback, ms === 1500 ? 0 : ms), clearTimeout,
  window: { location: { search: '?vk_client=ok&vk_app_id=999&vk_user_id=123&sign=test' }, addEventListener() {} },
  document: { visibilityState: 'visible', addEventListener: (type, cb) => listeners.set(type, cb) },
  vkBridge: {
    subscribe: cb => { subscriber = cb; },
    send: async method => { calls.push(method); if (method === 'VKWebAppInit') return {}; if (method === 'VKWebAppShowOrderBox') { orderStarted = true; return { result: true }; } throw Error('Unsupported platform'); }
  },
  fetch: async (url, options) => {
    if (offline) throw Error('Offline');
    if (legacyServer && !url.endsWith('/progress')) return { ok: true, json: async () => ({ product_id: 'remove_ads', price: '299 голосов VK', verified: true, remove_ads: true }) };
    if (url.endsWith('/catalog')) return { ok: true, json: async () => catalogEnabled
      ? { site: 'ok', product_id: 'remove_ads', title: 'Отключить рекламу', price: '199 ОКов' } : { site: 'ok' } };
    if (url.endsWith('/entitlements')) {
      if (orderStarted && ++entitlementReads >= 3) owned = true;
      return { ok: true, json: async () => ({ site: 'ok', verified: true, remove_ads: owned }) };
    }
    assert.ok(url.endsWith('/vk/payments/progress'));
    const params = new URLSearchParams(options.body);
    assert.equal(params.get('vk_client'), 'ok');
    assert.equal(params.get('vk_user_id'), '123');
    assert.equal(options.credentials, 'omit');
    if (params.has('progress')) saved = JSON.parse(params.get('progress'));
    return { ok: true, json: async () => ({ success: true, data: saved || null }) };
  }
};
vm.runInNewContext(source, context);
const bridge = context.window.ClownSmashPlatform;
const invoke = (method, ...args) => new Promise(resolve => bridge[method](...args, value => resolve(JSON.parse(value))));
bridge.configureVkPayments('https://game.example');
assert.equal((await invoke('initialize')).platform, 'ok');
assert.equal(bridge.getSaveProfile(), 'ok_999_123');
bridge.subscribeLifecycle(() => paused++, () => resumed++);
subscriber({ detail: { type: 'VKWebAppViewHide' } });
subscriber({ detail: { type: 'VKWebAppViewHide' } });
context.document.visibilityState = 'hidden'; listeners.get('visibilitychange')();
subscriber({ detail: { type: 'VKWebAppViewRestore' } });
assert.equal(paused, 1); assert.equal(resumed, 0);
context.document.visibilityState = 'visible'; listeners.get('visibilitychange')();
assert.equal(resumed, 1);
assert.equal((await invoke('checkAdAvailability')).available, false);
assert.equal((await invoke('setBannerVisible', true)).visible, false);
assert.equal((await invoke('loadProductCatalog')).product_id, undefined);
assert.equal((await invoke('restorePurchases')).remove_ads, false);
offline = true;
assert.equal((await invoke('purchase', 'remove_ads')).success, false);
assert.ok(!calls.includes('VKWebAppShowOrderBox'));
offline = false;
catalogEnabled = true;
assert.equal((await invoke('loadProductCatalog')).price, '199 ОКов');
assert.equal((await invoke('purchase', 'remove_ads')).success, true);
assert.ok(entitlementReads >= 3, 'OK mobile waits for durable server confirmation');
assert.equal((await invoke('restorePurchases')).remove_ads, true);
legacyServer = true;
assert.deepEqual(await invoke('loadProductCatalog'), {});
assert.equal((await invoke('restorePurchases')).remove_ads, undefined, 'legacy VK rights cannot leak into OK');
assert.equal((await invoke('purchase', 'remove_ads')).success, false);
legacyServer = false;
assert.equal((await invoke('loadCloudSave')).data, null);
const first = { save_version: 1, highest_unlocked_level: 2 };
await invoke('saveCloudSave', JSON.stringify(first));
assert.deepEqual((await invoke('loadCloudSave')).data, first);
const writes = [3, 4, 5].map(level => invoke('saveCloudSave', JSON.stringify({ highest_unlocked_level: level })));
await Promise.all(writes);
assert.equal(saved.highest_unlocked_level, 5);
offline = true;
assert.equal((await invoke('saveCloudSave', '{}')).success, false);
offline = false;
assert.equal((await invoke('saveCloudSave', JSON.stringify(first))).success, true);
console.log('OK BRIDGE TEST: PASS');
