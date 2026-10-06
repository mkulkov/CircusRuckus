import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const shell = fs.readFileSync(new URL('../web/portrait_shell.html', import.meta.url), 'utf8');
const source = shell.match(/\/\/ A small host API[\s\S]*?<\/script>/)[0].replace(/<\/script>$/, '');
const flush = async () => { for (let i = 0; i < 8; i++) await new Promise(resolve => setImmediate(resolve)); };

function setup() {
  const calls = [];
  const listeners = new Map();
  const state = { owned: false, confirmed: true, status: 'success', reject: false, networkFailure: false, pending: false, pauses: 0, resumes: 0 };
  let orderTimeout;
  const context = {
    console, URL, URLSearchParams, AbortController,
    setTimeout(callback, ms) { if (ms === 180000) { orderTimeout = callback; return 'order'; } return setTimeout(callback, ms); },
    clearTimeout(id) { if (id !== 'order') clearTimeout(id); },
    window: { location: { search: '?vk_app_id=54768735&vk_user_id=123&sign=signed' }, addEventListener: (name, cb) => listeners.set(name, cb) },
    document: { visibilityState: 'visible', addEventListener: (name, cb) => listeners.set(name, cb) },
    fetch: async (url, options) => {
      calls.push({ url, options });
      if (state.networkFailure) throw new Error('Offline');
      if (state.delayNextRestore && url.endsWith('/entitlements')) {
        state.delayNextRestore = false;
        return { ok: true, json: () => new Promise(resolve => {
          state.releaseRestore = () => resolve({ verified: true, remove_ads: false });
        }) };
      }
      return { ok: true, json: async () => url.endsWith('/catalog')
        ? { product_id: 'remove_ads', title: 'Отключить рекламу', price: '299 голосов VK' }
        : { verified: true, remove_ads: state.owned } };
    },
    vkBridge: { send: async (method, options) => {
      calls.push({ method, options });
      if (method === 'VKWebAppInit') return { result: true };
      if (method.includes('Ads') || method.includes('BannerAd')) {
        if (state.adReject) throw new Error('No ads');
        return { result: state.adResult !== false };
      }
      if (method === 'VKWebAppShowOrderBox') {
        if (state.reject) throw new Error('Cancelled');
        if (state.pending) return new Promise(() => {});
        if (state.status === 'success' && state.confirmed) state.owned = true;
        return { status: state.status };
      }
      return { result: true };
    } }
  };
  vm.runInNewContext(source, context);
  const bridge = context.window.ClownSmashPlatform;
  bridge.initialize(() => {});
  bridge.subscribeLifecycle(() => state.pauses++, () => state.resumes++);
  return { bridge, state, calls, listeners, expireOrder: () => orderTimeout() };
}

for (const adResult of [true, false]) {
  const { bridge, state } = setup(); await flush(); state.adResult = adResult;
  let availability; bridge.checkAdAvailability(value => availability = JSON.parse(value)); await flush();
  assert.equal(availability.available, adResult);
  let banner; bridge.setBannerVisible(true, value => banner = JSON.parse(value)); await flush();
  assert.equal(banner.visible, adResult);
  let interstitial; bridge.showInterstitial(() => {}, value => interstitial = JSON.parse(value)); await flush();
  assert.equal(interstitial.success, adResult, 'SDK result:false must not count as a shown ad');
}
{
  const { bridge, state } = setup(); await flush(); state.adReject = true;
  let availability; bridge.checkAdAvailability(value => availability = JSON.parse(value)); await flush();
  assert.equal(availability.available, false);
  let result; bridge.showInterstitial(() => {}, value => result = JSON.parse(value)); await flush();
  assert.equal(result.success, false);
}

{
  const { bridge, calls } = setup(); await flush();
  let product; bridge.loadProductCatalog(value => product = JSON.parse(value)); await flush();
  assert.deepEqual(product, {}, 'without server configuration the offer stays unavailable');
  let purchase; bridge.purchase('remove_ads', value => purchase = JSON.parse(value));
  assert.equal(purchase.success, false); assert.equal(calls.some(c => c.method === 'VKWebAppShowOrderBox'), false);
  bridge.configureVkPayments('http://unsafe.example');
  bridge.purchase('remove_ads', value => purchase = JSON.parse(value));
  assert.equal(purchase.success, false);
}

{
  const { bridge, state, calls, listeners } = setup(); await flush();
  bridge.configureVkPayments('https://payments.example');
  let product; bridge.loadProductCatalog(value => product = JSON.parse(value)); await flush();
  assert.equal(product.price, '299 голосов VK');
  assert.ok(calls.find(c => c.url)?.options.body.includes('sign=signed'));
  let restored; bridge.subscribeVkEntitlements(value => restored = JSON.parse(value));
  bridge.restorePurchases(value => restored = JSON.parse(value)); await flush();
  assert.equal(restored.remove_ads, false);
  let purchase; bridge.purchase('remove_ads', value => purchase = JSON.parse(value)); await flush();
  assert.equal(purchase.success, true); assert.equal(state.pauses, 1); assert.equal(state.resumes, 1);
  assert.equal(calls.filter(c => c.method === 'VKWebAppShowOrderBox').length, 1);
  bridge.purchase('remove_ads', () => {}); await flush();
  assert.equal(calls.filter(c => c.method === 'VKWebAppShowOrderBox').length, 1, 'owned product is not charged again');
  state.owned = false; listeners.get('focus')(); await flush();
  assert.equal(restored.remove_ads, false, 'refund/account rights are refreshed on focus');
}

for (const changes of [{ reject: true }, { status: 'cancel' }, { status: 'fail' }, { confirmed: false }, { networkFailure: true }]) {
  const { bridge, state } = setup(); await flush(); bridge.configureVkPayments('https://payments.example');
  Object.assign(state, changes);
  let purchase; let count = 0;
  bridge.purchase('remove_ads', value => { purchase = JSON.parse(value); count++; }); await flush();
  assert.equal(purchase.success, false, JSON.stringify(changes));
  assert.equal(count, 1); assert.equal(state.pauses, state.resumes, 'terminal paths release pause');
}

{
  const { bridge, state, calls, expireOrder } = setup(); await flush(); bridge.configureVkPayments('https://payments.example');
  state.pending = true; let first; let second;
  bridge.purchase('remove_ads', value => first = JSON.parse(value)); await flush();
  bridge.purchase('remove_ads', value => second = JSON.parse(value));
  assert.equal(second.success, false);
  assert.equal(calls.filter(c => c.method === 'VKWebAppShowOrderBox').length, 1);
  expireOrder(); await flush();
  assert.equal(first.success, false); assert.equal(state.pauses, state.resumes);
}

{
  const { bridge, state } = setup(); await flush(); bridge.configureVkPayments('https://payments.example');
  state.delayNextRestore = true; let staleRestores = 0;
  bridge.restorePurchases(() => staleRestores++); await flush();
  let purchase; bridge.purchase('remove_ads', value => purchase = JSON.parse(value)); await flush();
  assert.equal(purchase.success, true);
  state.releaseRestore(); await flush();
  assert.equal(staleRestores, 0, 'an old restore cannot revoke a newly confirmed purchase');
}

console.log('VK BRIDGE TEST: PASS');
