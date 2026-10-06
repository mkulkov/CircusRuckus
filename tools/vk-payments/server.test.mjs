import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, createHmac } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, basename } from 'node:path';
import { createPaymentService, createPaymentServer, parseForm, verifyLaunch, isVkHostingOrigin } from './server.mjs';

test('VK hosting patterns are restricted to each app and generated host templates', () => {
  for (const origin of ['https://stage-app54768735-8edda10463a2.pages.vk-apps.ru', 'https://prod-app54768735-bf3491f22412.pages-ac.vk-apps.ru']) {
    assert.equal(isVkHostingOrigin(origin, '54768735'), true);
  }
  for (const origin of ['https://stage-app54801268-291e84639eff.pages.vk-apps.ru',
    'https://stage-app54801268-aabbccddeeff.pages.vk-apps.ru',
    'https://prod-app54801268-0123456789ab.pages-ac.vk-apps.ru']) {
    assert.equal(isVkHostingOrigin(origin, '54801268'), true);
  }
  for (const origin of [undefined, 'null', 'http://stage-app54768735-8edda10463a2.pages.vk-apps.ru',
    'https://stage-app12345678-8edda10463a2.pages.vk-apps.ru',
    'https://stage-app54768735-8edda10463a2.pages.vk-apps.ru.evil.com',
    'https://stage-app54768735-8edda10463a2.pages.vk-apps.ru:443',
    'https://stage-app54768735-8edda10463a2.pages.vk-apps.ru/path',
    'https://user@stage-app54768735-8edda10463a2.pages.vk-apps.ru']) {
    assert.equal(isVkHostingOrigin(origin, '54768735'), false, String(origin));
  }
});

test('generated VK Hosting origins work without pinning a rotating hash', async () => {
  const service = createPaymentService(config);
  const server = createPaymentServer(service, []);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const origin of ['https://stage-app54768735-8edda10463a2.pages.vk-apps.ru',
      'https://stage-app54768735-aabbccddeeff.pages.vk-apps.ru',
      'https://prod-app54768735-bf3491f22412.pages-ac.vk-apps.ru']) {
      const response = await fetch(base + '/vk/payments/catalog', { method: 'OPTIONS', headers: { Origin: origin } });
      assert.equal(response.status, 204);
      assert.equal(response.headers.get('access-control-allow-origin'), origin);
    }
    const denied = await fetch(base + '/vk/payments/catalog', { method: 'OPTIONS', headers: { Origin: 'https://attacker.example' } });
    assert.equal(denied.status, 403);
  } finally { await new Promise(resolve => server.close(resolve)); service.close(); }
});

const config = { appId: '54768735', secret: 'unit-test-secret', mode: 'test', price: 299, databasePath: ':memory:' };
const sign = params => ({ ...params, sig: createHash('md5').update(Object.keys(params).sort().map(k => `${k}=${params[k]}`).join('') + config.secret).digest('hex') });
const order = overrides => sign({ app_id: config.appId, notification_type: 'order_status_change_test',
  order_id: '42', receiver_id: '123', user_id: '123', item: 'remove_ads', item_id: 'vk-item',
  item_price: '299', status: 'chargeable', ...overrides });
const launch = overrides => {
  const params = { vk_app_id: config.appId, vk_user_id: '123', vk_ts: String(Math.floor(Date.now() / 1000)), vk_language: 'ru', ...overrides };
  params.sign = createHmac('sha256', config.secret).update(Object.keys(params).sort().map(k => `${k}=${encodeURIComponent(params[k])}`).join('&')).digest('base64url');
  return params;
};

test('signed catalog, price and unknown products', () => {
  const service = createPaymentService(config);
  try {
    const params = sign({ app_id: config.appId, user_id: '123', receiver_id: '123', order_id: '1', item: 'remove_ads', notification_type: 'get_item_test', lang: 'ru_RU' });
    assert.equal(service.callback(params).response.price, 299);
    assert.equal(service.catalog(launch()).price, '299 голосов VK');
    const { sig, ...unsigned } = params;
    assert.equal(service.callback(sign({ ...unsigned, notification_type: 'get_item' })).response.price, 299);
    assert.equal(service.entitlement(launch()).remove_ads, false, 'catalog lookup never grants rights');
    assert.equal(service.callback(order({ notification_type: 'order_status_change' })).error.error_code, 11, 'live payment cannot grant test rights');
    assert.equal(service.callback(sign({ ...unsigned, item: 'unknown' })).error.error_code, 20);
    assert.equal(service.callback({ ...params, sig: 'bad' }).error.error_code, 10);
  } finally { service.close(); }
});

test('idempotent orders, refunds and no resurrection by late retries', () => {
  const service = createPaymentService(config);
  try {
    const first = service.callback(order());
    assert.ok(first.response.app_order_id);
    assert.deepEqual(service.callback(order()), first);
    assert.equal(service.entitlement(launch()).remove_ads, true);
    assert.equal(service.callback(order({ receiver_id: '456' })).error.error_code, 11);
    assert.equal(service.callback(order({ order_id: '44', item_price: '1' })).error.error_code, 11);
    assert.equal(service.callback(order({ order_id: '44', item_discount: '1' })).error.error_code, 11);
    assert.equal(service.callback(order({ app_id: '1' })).error.error_code, 11);
    assert.deepEqual(service.callback(order({ status: 'refunded' })), first);
    assert.equal(service.entitlement(launch()).remove_ads, false);
    assert.deepEqual(service.callback(order()), first);
    assert.equal(service.entitlement(launch()).remove_ads, false);
    service.callback(order({ order_id: '43' }));
    assert.equal(service.entitlement(launch()).remove_ads, true);
    service.callback(order({ status: 'refunded' }));
    assert.equal(service.entitlement(launch()).remove_ads, true, 'another paid order survives this refund');
    service.callback(order({ order_id: '43', status: 'refunded' }));
    assert.equal(service.entitlement(launch()).remove_ads, false);
    service.callback(order({ order_id: '45', status: 'refunded' }));
    service.callback(order({ order_id: '45' }));
    assert.equal(service.entitlement(launch()).remove_ads, false, 'out-of-order refund stays terminal');
    assert.equal(service.entitlement(launch({ vk_user_id: '456' })).remove_ads, false);
  } finally { service.close(); }
});

test('durable ledger restores across restart; test rights never become live', () => {
  const dir = mkdtempSync(join(tmpdir(), 'clown-vk-payments-'));
  const saved = { ...config, databasePath: join(dir, 'orders.sqlite') };
  try {
    let service = createPaymentService(saved);
    service.callback(order());
    service.progress({ ...launch(), progress: JSON.stringify(progress()) }); service.close();
    service = createPaymentService(saved);
    assert.equal(service.entitlement(launch()).remove_ads, true);
    assert.equal(service.progress(launch()).data.best_scores["1"], 100); service.close();
    service = createPaymentService({ ...saved, mode: 'live' });
    assert.equal(service.entitlement(launch()).remove_ads, false);
    assert.equal(service.callback(order()).error.error_code, 11);
    service.callback(order({ notification_type: 'order_status_change' }));
    assert.equal(service.entitlement(launch()).remove_ads, true); service.close();
  } finally {
    assert.equal(resolve(dirname(dir)), resolve(tmpdir()));
    assert.ok(basename(dir).startsWith('clown-vk-payments-'));
    rmSync(dir, { recursive: true, force: true });
  }
});

test('launch authentication rejects wrong app, old timestamp, forged user and duplicate params', () => {
  assert.equal(verifyLaunch(launch(), config), true);
  assert.equal(verifyLaunch({ ...launch(), vk_user_id: '456' }, config), false);
  assert.equal(verifyLaunch(launch({ vk_app_id: '1' }), config), false);
  assert.equal(verifyLaunch(launch({ vk_ts: '1' }), config), false);
  assert.throws(() => parseForm('vk_user_id=123&vk_user_id=456'));
  const unicode = parseForm(new URLSearchParams({ title: 'Отключить рекламу + навсегда' }).toString());
  assert.equal(unicode.title, 'Отключить рекламу + навсегда');
});

test('HTTP authentication, origin restrictions and signed callback transport', async () => {
  const service = createPaymentService(config);
  const server = createPaymentServer(service, ['https://game.example']);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const request = (path, params, origin = 'https://game.example') => fetch(base + '/vk/payments/' + path, {
    method: 'POST', headers: { Origin: origin, 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(params)
  });
  try {
    assert.equal((await request('catalog', launch(), 'https://attacker.example')).status, 403);
    assert.equal((await request('catalog', { ...launch(), vk_user_id: '456' })).status, 401);
    const catalog = await request('catalog', launch());
    assert.equal(catalog.headers.get('access-control-allow-origin'), 'https://game.example');
    assert.equal((await catalog.json()).price, '299 голосов VK');
    assert.ok((await (await request('callback', order(), '')).json()).response);
    assert.equal((await (await request('entitlements', launch())).json()).remove_ads, true);
  } finally { await new Promise(resolve => server.close(resolve)); service.close(); }
});

const progress = overrides => ({ save_version: 1, highest_unlocked_level: 2, completed_levels: [1],
  best_scores: { '1': 100 }, best_combos: { '1': 4 }, music_enabled: true, sound_enabled: true,
  haptics_enabled: true, ads_removed: true, ...overrides });

test('progress merges devices without losing achievements and never grants payment rights', () => {
  const service = createPaymentService(config);
  try {
    const user = launch();
    service.progress({ ...user, progress: JSON.stringify(progress()) });
    const result = service.progress({ ...user, progress: JSON.stringify(progress({ highest_unlocked_level: 3,
      completed_levels: [2], best_scores: { '1': 50, '2': 200 }, best_combos: { '1': 2 }, music_enabled: false })) });
    assert.deepEqual(result.data.completed_levels, [1, 2]);
    assert.equal(result.data.highest_unlocked_level, 3);
    assert.equal(result.data.best_scores['1'], 100);
    assert.equal(result.data.best_combos['1'], 4);
    assert.equal(result.data.music_enabled, false);
    assert.equal(result.data.ads_removed, false);
    assert.equal(service.entitlement(user).remove_ads, false);
    assert.equal(service.progress(launch({ vk_user_id: '456' })).data, null);
    assert.throws(() => service.progress({ ...user, progress: JSON.stringify(progress({ best_scores: { '__proto__': 1, '10': 2 } })) }));
    assert.equal(service.progress(user).data.highest_unlocked_level, 3);
  } finally { service.close(); }
});

test('OK launch signatures and progress are separated from VK even for identical user IDs', () => {
  const service = createPaymentService({ ...config, okAppId: '999' });
  try {
    const ok = launch({ vk_client: 'ok', vk_app_id: '999' });
    assert.equal(verifyLaunch(ok, service.config), true);
    assert.equal(verifyLaunch({ ...ok, vk_client: 'vk' }, service.config), false);
    assert.equal(verifyLaunch(launch({ vk_client: 'evil' }), service.config), false);
    service.progress({ ...ok, progress: JSON.stringify(progress()) });
    assert.equal(service.progress(launch()).data, null);
    assert.equal(service.progress(ok).data.best_scores['1'], 100);
    service.callback(order());
    assert.equal(service.entitlement(ok).remove_ads, false);
    assert.deepEqual(service.catalog(ok), {});
    assert.equal(service.entitlement(launch()).remove_ads, true);
  } finally { service.close(); }
});

test('progress HTTP endpoint rejects forged identities and invalid saves', async () => {
  const service = createPaymentService(config), server = createPaymentServer(service, ['https://game.example']);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}/vk/payments/progress`;
  const request = params => fetch(url, { method: 'POST', headers: { Origin: 'https://game.example',
    'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(params) });
  try {
    assert.equal((await request({ ...launch(), vk_client: 'ok', progress: JSON.stringify(progress()) })).status, 401);
    assert.equal((await request({ ...launch(), progress: '{bad' })).status, 400);
    assert.equal((await request({ ...launch(), progress: JSON.stringify(progress()) })).status, 200);
    assert.equal((await (await request(launch())).json()).data.highest_unlocked_level, 2);
  } finally { await new Promise(resolve => server.close(resolve)); service.close(); }
});

const okConfig = { ...config, okAppId: '999', okPublicKey: 'OK_PUBLIC', okSecret: 'ok-test-secret', okMode: 'test', okPrice: 199 };
const okLaunch = () => launch({ vk_client: 'ok', vk_app_id: '999' });
const okPayment = overrides => {
  const value = { application_key: 'OK_PUBLIC', method: 'callbacks.payment', uid: '123', transaction_id: '900',
    transaction_time: '2026-10-01 12:00:00', amount: '199', product_code: 'remove_ads', extra_attributes: '', ...overrides };
  return { ...value, sig: createHash('md5').update(Object.keys(value).sort().map(k => `${k}=${value[k]}`).join('') + okConfig.okSecret).digest('hex') };
};

test('OK price, signature, duplicate callbacks, refund tombstones and VK isolation', () => {
  const service = createPaymentService(okConfig);
  try {
    assert.equal(service.catalog(okLaunch()).price, '199 ОКов');
    const item = order({ notification_type: 'get_item_test', site: 'OK' });
    assert.equal(service.callback(item).response.price, 199);
    assert.equal(service.entitlement(okLaunch()).remove_ads, false);
    assert.equal(service.okCallback(okPayment({ amount: '1' }), 'test').error_code, 1001);
    assert.equal(service.okCallback({ ...okPayment(), sig: 'bad' }, 'test').error_code, 104);
    assert.equal(service.okCallback(okPayment({ application_key: 'FOREIGN' }), 'test').error_code, 1001);
    assert.equal(service.okCallback(okPayment(), 'live').error_code, 1001);
    assert.equal(service.okCallback(okPayment({ extra_attributes: '{"action":"reg_subscription"}' }), 'test').error_code, 1001);
    assert.equal(service.okCallback(okPayment(), 'test'), true);
    assert.equal(service.okCallback(okPayment(), 'test'), true);
    assert.equal(service.entitlement(okLaunch()).remove_ads, true);
    assert.equal(service.entitlement(launch()).remove_ads, false);
    assert.equal(service.okCallback(okPayment({ uid: '456' }), 'test').error_code, 1001);
    assert.throws(() => service.recordOkRefund('900', '456'));
    service.recordOkRefund('900', '123');
    assert.equal(service.entitlement(okLaunch()).remove_ads, false);
    assert.equal(service.okCallback(okPayment(), 'test'), true);
    assert.equal(service.entitlement(okLaunch()).remove_ads, false, 'late callback cannot resurrect refund');
  } finally { service.close(); }
});

test('OK GET callback URL decoding, response and Invocation-error contract', async () => {
  const service = createPaymentService(okConfig), server = createPaymentServer(service, ['https://game.example']);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const get = (params, mode = 'test') => fetch(`${base}/ok/payments/callback/${mode}?${new URLSearchParams(params)}`);
  try {
    const invalid = await get(okPayment({ amount: '1' }));
    assert.equal(invalid.headers.get('invocation-error'), '1001');
    assert.equal((await invalid.json()).error_code, 1001);
    const valid = await get(okPayment({ transaction_time: '2026-10-01 12:00:00' }));
    assert.equal(valid.headers.get('content-type'), 'application/json; charset=utf-8');
    assert.equal(await valid.json(), true);
    assert.equal((await get({ ...okPayment(), uid: '456' })).headers.get('invocation-error'), '104');
    assert.equal((await get(okPayment(), 'live')).headers.get('invocation-error'), '1001');
    const duplicate = await fetch(`${base}/ok/payments/callback/test?${new URLSearchParams(okPayment())}&uid=456`);
    assert.equal(duplicate.headers.get('invocation-error'), '1001');
    assert.equal((await fetch(base + '/ok/payments/callback/test', { method: 'POST' })).status, 405);
  } finally { await new Promise(resolve => server.close(resolve)); service.close(); }
});

test('OK payments survive server restart and test rights never migrate to live', () => {
  const dir = mkdtempSync(join(tmpdir(), 'clown-ok-payments-'));
  const disk = { ...okConfig, databasePath: join(dir, 'orders.sqlite') };
  try {
    let service = createPaymentService(disk);
    assert.equal(service.okCallback(okPayment(), 'test'), true); service.close();
    service = createPaymentService(disk);
    assert.equal(service.entitlement(okLaunch()).remove_ads, true); service.close();
    service = createPaymentService({ ...disk, okMode: 'live' });
    assert.equal(service.entitlement(okLaunch()).remove_ads, false);
    assert.equal(service.okCallback(okPayment(), 'test').error_code, 1001);
    assert.equal(service.okCallback(okPayment(), 'live'), true);
    assert.equal(service.entitlement(okLaunch()).remove_ads, true); service.close();
  } finally {
    assert.equal(resolve(dirname(dir)), resolve(tmpdir()));
    assert.ok(basename(dir).startsWith('clown-ok-payments-'));
    rmSync(dir, { recursive: true, force: true });
  }
});

test('current OK launcher uses VK app ID, OK app/user IDs and millisecond timestamp', () => {
  const service = createPaymentService(okConfig);
  try {
    const params = launch({ vk_client: 'ok', vk_ok_app_id: '999', vk_ok_user_id: '123', vk_user_id: '456', vk_ts: String(Date.now()) });
    assert.equal(verifyLaunch(params, okConfig), true);
    assert.equal(verifyLaunch(launch({ vk_client: 'ok', vk_ok_app_id: '998', vk_ts: String(Date.now()) }), okConfig), false);
    assert.equal(verifyLaunch(launch({ vk_client: 'ok', vk_ok_app_id: '999', vk_ts: String(Date.now() - 86401000) }), okConfig), false);
    assert.equal(verifyLaunch({ ...params, vk_ok_user_id: '789' }, okConfig), false);
    assert.equal(service.okCallback(okPayment({}), 'test'), true);
    assert.equal(service.entitlement(params).remove_ads, true);
    assert.equal(service.entitlement({ ...params, vk_ok_user_id: '789' }).remove_ads, false);
  } finally { service.close(); }
});