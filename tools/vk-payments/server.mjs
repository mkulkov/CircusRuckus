import { createServer } from 'node:http';
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const PRODUCT = 'remove_ads';
const positiveId = value => /^[1-9]\d*$/.test(value || '') && Number.isSafeInteger(Number(value));
const equal = (a, b) => typeof a === 'string' && typeof b === 'string' &&
  Buffer.byteLength(a) === Buffer.byteLength(b) && timingSafeEqual(Buffer.from(a), Buffer.from(b));
const vkError = (code, message, critical = true) => ({ error: { error_code: code, error_msg: message, critical } });

export function parseForm(encoded) {
  const result = Object.create(null);
  for (const [key, value] of new URLSearchParams(encoded)) {
    if (Object.hasOwn(result, key)) throw new Error('Duplicate parameter');
    result[key] = value;
  }
  return result;
}

export function verifyCallback(params, secret) {
  const text = Object.keys(params).filter(key => key !== 'sig').sort()
    .map(key => `${key}=${params[key]}`).join('') + secret;
  return equal(createHash('md5').update(text).digest('hex'), params.sig);
}

export function verifyLaunch(params, config, now = Date.now()) {
  const query = Object.keys(params).filter(key => key.startsWith('vk_')).sort()
    .map(key => `${key}=${encodeURIComponent(params[key])}`).join('&');
  const signature = createHmac('sha256', config.secret).update(query).digest('base64url');
  const rawTimestamp = Number(params.vk_ts);
  const timestamp = params.vk_client === 'ok' && rawTimestamp >= 1e12 ? rawTimestamp / 1000 : rawTimestamp;
  const site = params.vk_client === 'ok' ? 'ok' : 'vk';
  if (params.vk_client && !['ok', 'vk'].includes(params.vk_client)) return false;
  const appMatches = site === 'ok' && params.vk_ok_app_id
    ? params.vk_app_id === config.appId && params.vk_ok_app_id === config.okAppId
    : params.vk_app_id === (site === 'ok' ? (config.okAppId || config.appId) : config.appId);
  return appMatches && positiveId(params.vk_user_id) &&
    (site !== 'ok' || !params.vk_ok_user_id || positiveId(params.vk_ok_user_id)) && Number.isSafeInteger(rawTimestamp) && timestamp <= now / 1000 + 300 &&
    timestamp >= now / 1000 - 86400 && equal(signature, params.sign);
}

export function createPaymentService(config) {
  if (!positiveId(config.appId) || (config.okAppId && !positiveId(config.okAppId)) || !config.secret || !['test', 'live'].includes(config.mode) ||
      !Number.isSafeInteger(config.price) || config.price <= 0) throw new Error('Invalid VK payment configuration');
  if (config.databasePath !== ':memory:') mkdirSync(dirname(resolve(config.databasePath)), { recursive: true });
  if (config.okPrice !== undefined && (!Number.isSafeInteger(config.okPrice) || config.okPrice <= 0)) throw new Error('Invalid OK price');
  if (config.okMode && !['test', 'live'].includes(config.okMode)) throw new Error('Invalid OK mode');
  const okEnabled = !!(config.okAppId && config.okPublicKey && config.okPrice && config.okMode);
  const db = new DatabaseSync(config.databasePath);
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT, mode TEXT NOT NULL, order_id TEXT NOT NULL,
      user_id TEXT NOT NULL, receiver_id TEXT NOT NULL, item TEXT NOT NULL,
      item_id TEXT NOT NULL, price INTEGER NOT NULL, status TEXT NOT NULL,
      UNIQUE(mode, order_id)
    );`);
  db.exec(`CREATE TABLE IF NOT EXISTS progress (
    site TEXT NOT NULL, app_id TEXT NOT NULL, user_id TEXT NOT NULL, data TEXT NOT NULL,
    PRIMARY KEY(site, app_id, user_id));`);
  const getProgress = db.prepare('SELECT data FROM progress WHERE site=? AND app_id=? AND user_id=?');
  const putProgress = db.prepare('INSERT INTO progress(site,app_id,user_id,data) VALUES(?,?,?,?) ON CONFLICT(site,app_id,user_id) DO UPDATE SET data=excluded.data');
  const identity = params => [params.vk_client === 'ok' ? 'ok' : 'vk', params.vk_app_id, params.vk_user_id];
  db.exec(`CREATE TABLE IF NOT EXISTS ok_orders (
    mode TEXT NOT NULL, app_id TEXT NOT NULL, transaction_id TEXT NOT NULL, user_id TEXT NOT NULL,
    item TEXT NOT NULL, price INTEGER NOT NULL, status TEXT NOT NULL,
    PRIMARY KEY(mode, app_id, transaction_id));`);
  const okOrder = db.prepare('SELECT * FROM ok_orders WHERE mode=? AND app_id=? AND transaction_id=?');
  const okOwned = db.prepare("SELECT 1 FROM ok_orders WHERE mode=? AND app_id=? AND user_id=? AND item=? AND status='chargeable' LIMIT 1");
  const findOrder = db.prepare('SELECT * FROM orders WHERE mode=? AND order_id=?');
  const hasEntitlement = db.prepare("SELECT 1 FROM orders WHERE mode=? AND receiver_id=? AND item=? AND status='chargeable' LIMIT 1");
  const title = language => language?.startsWith('en') ? 'Disable ads' : 'Отключить рекламу';
  return {
    config,
    close: () => db.close(),
    catalog(params) {
      if (params.vk_client === 'ok') return okEnabled ? { site: 'ok', product_id: PRODUCT, title: title(params.vk_language),
        price: `${config.okPrice} ${params.vk_language?.startsWith('en') ? 'OKs' : 'ОКов'}`, mode: config.okMode } : {};
      return { product_id: PRODUCT, title: title(params.vk_language),
        price: `${config.price} ${params.vk_language?.startsWith('en') ? 'VK votes' : 'голосов VK'}`, mode: config.mode };
    },
    entitlement(params) {
      if (params.vk_client === 'ok') return { site: 'ok', verified: true, remove_ads: okEnabled && !!okOwned.get(config.okMode, config.okAppId, params.vk_ok_user_id || params.vk_user_id, PRODUCT), mode: config.okMode || 'disabled' };
      return { verified: true, remove_ads: !!hasEntitlement.get(config.mode, params.vk_user_id, PRODUCT), mode: config.mode };
    },
    progress(params) {
      const key = identity(params);
      const current = getProgress.get(...key);
      if (!Object.hasOwn(params, 'progress')) return { success: true, data: current ? JSON.parse(current.data) : null };
      const incoming = normalizeProgress(JSON.parse(params.progress));
      db.exec('BEGIN IMMEDIATE');
      try {
        const row = getProgress.get(...key);
        const previous = row ? JSON.parse(row.data) : null;
        if (previous) {
          incoming.highest_unlocked_level = Math.max(previous.highest_unlocked_level, incoming.highest_unlocked_level);
          incoming.completed_levels = [...new Set([...previous.completed_levels, ...incoming.completed_levels])].sort((a,b) => a-b);
          for (const field of ['best_scores', 'best_combos']) for (const [level, value] of Object.entries(previous[field])) {
            incoming[field][level] = Math.max(value, incoming[field][level] || 0);
          }
        }
        putProgress.run(...key, JSON.stringify(incoming));
        db.exec('COMMIT');
        return { success: true, data: incoming };
      } catch (error) { db.exec('ROLLBACK'); throw error; }
    },
    okCallback(params, mode) {
      const error = (code, message) => ({ error_code: code, error_msg: message, error_data: null });
      if (!okEnabled || mode !== config.okMode) return error(1001, 'OK payments not configured for this mode');
      if (!verifyCallback(params, config.okSecret || config.secret)) return error(104, 'Invalid signature');
      let attributes;
      try { attributes = params.extra_attributes ? JSON.parse(params.extra_attributes) : {}; }
      catch { return error(1001, 'Invalid attributes'); }
      if (params.application_key !== config.okPublicKey || params.method !== 'callbacks.payment' ||
          !positiveId(params.uid) || !positiveId(params.transaction_id) || !params.transaction_time ||
          params.product_code !== PRODUCT || !positiveId(params.amount) ||
          (params.currency && params.currency !== 'ok') ||
          !attributes || typeof attributes !== 'object' || Object.keys(attributes).length) return error(1001, 'Invalid payment');
      db.exec('BEGIN IMMEDIATE');
      try {
        const previous = okOrder.get(mode, config.okAppId, params.transaction_id);
        if (previous) {
          if (previous.user_id !== params.uid || previous.item !== params.product_code || previous.price !== Number(params.amount)) {
            db.exec('ROLLBACK'); return error(1001, 'Transaction identity mismatch');
          }
        } else {
          if (Number(params.amount) !== config.okPrice) { db.exec('ROLLBACK'); return error(1001, 'Incorrect price'); }
          db.prepare("INSERT INTO ok_orders(mode,app_id,transaction_id,user_id,item,price,status) VALUES(?,?,?,?,?,?,'chargeable')")
            .run(mode, config.okAppId, params.transaction_id, params.uid, PRODUCT, config.okPrice);
        }
        db.exec('COMMIT');
        return true;
      } catch { db.exec('ROLLBACK'); return error(2, 'Payment storage unavailable'); }
    },
    // Called locally only after the platform confirms refundUserPayment succeeded.
    recordOkRefund(transactionId, userId, mode = config.okMode) {
      const row = okOrder.get(mode, config.okAppId, transactionId);
      if (!row || row.user_id !== userId) throw new Error('Unknown OK transaction');
      db.prepare("UPDATE ok_orders SET status='refunded' WHERE mode=? AND app_id=? AND transaction_id=?")
        .run(mode, config.okAppId, transactionId);
    },
    callback(params) {
      if (!verifyCallback(params, config.secret)) return vkError(10, 'Invalid signature');
      const isOk = params.site === 'OK';
      if (isOk && okEnabled && [config.appId, config.okAppId].includes(params.app_id) &&
          ['get_item', 'get_item_test'].includes(params.notification_type)) {
        if (params.item !== PRODUCT) return vkError(20, 'Unknown product');
        return { response: { item_id: PRODUCT, title: title(params.lang), price: config.okPrice, expiration: 0 } };
      }
      if (params.app_id !== config.appId || !positiveId(params.user_id) || !positiveId(params.receiver_id) ||
          !positiveId(params.order_id) || (params.site && params.site !== 'VK')) return vkError(11, 'Invalid parameters');
      const suffix = config.mode === 'test' ? '_test' : '';
      // Catalog metadata grants no rights; VK may send the unsuffixed lookup in test checkout.
      if (['get_item', 'get_item_test'].includes(params.notification_type)) {
        if (params.item !== PRODUCT) return vkError(20, 'Unknown product');
        return { response: { item_id: PRODUCT, title: title(params.lang), price: config.price, expiration: 0 } };
      }
      if (params.notification_type !== `order_status_change${suffix}` ||
          !['chargeable', 'refunded'].includes(params.status) || params.item !== PRODUCT ||
          !params.item_id || !positiveId(params.item_price)) return vkError(11, 'Invalid order');
      // Commit the order before acknowledging VK. The unique key makes retries idempotent.
      db.exec('BEGIN IMMEDIATE');
      try {
        let order = findOrder.get(config.mode, params.order_id);
        if (order && (order.user_id !== params.user_id || order.receiver_id !== params.receiver_id ||
            order.item !== params.item || order.item_id !== params.item_id || order.price !== Number(params.item_price))) {
          db.exec('ROLLBACK');
          return vkError(11, 'Order identity mismatch');
        }
        if (!order) {
          if (Number(params.item_price) !== config.price || Number(params.item_discount || 0) !== 0) {
            db.exec('ROLLBACK');
            return vkError(11, 'Incorrect price');
          }
          db.prepare('INSERT INTO orders(mode,order_id,user_id,receiver_id,item,item_id,price,status) VALUES(?,?,?,?,?,?,?,?)')
            .run(config.mode, params.order_id, params.user_id, params.receiver_id, params.item, params.item_id, config.price, params.status);
          order = findOrder.get(config.mode, params.order_id);
        } else if (params.status === 'refunded') {
          db.prepare("UPDATE orders SET status='refunded' WHERE id=?").run(order.id);
        }
        // A late chargeable retry must never resurrect a refunded order.
        db.exec('COMMIT');
        return { response: { order_id: Number(params.order_id), app_order_id: order.id } };
      } catch {
        db.exec('ROLLBACK');
        return vkError(2, 'Payment storage unavailable', false);
      }
    }
  };
}


export function normalizeProgress(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || value.save_version !== 1 ||
      !Number.isInteger(value.highest_unlocked_level) || value.highest_unlocked_level < 1 || value.highest_unlocked_level > 9 ||
      !Array.isArray(value.completed_levels) || value.completed_levels.length > 9 ||
      value.completed_levels.some(level => !Number.isInteger(level) || level < 1 || level > 9)) throw new Error('Invalid progress');
  const result = { save_version: 1, highest_unlocked_level: value.highest_unlocked_level,
    completed_levels: [...new Set(value.completed_levels)].sort((a,b) => a-b), ads_removed: false };
  for (const field of ['best_scores', 'best_combos']) {
    if (!value[field] || typeof value[field] !== 'object' || Array.isArray(value[field])) throw new Error('Invalid scores');
    result[field] = {};
    for (const [level, score] of Object.entries(value[field])) {
      if (!/^[1-9]$/.test(level) || !Number.isSafeInteger(score) || score < 0) throw new Error('Invalid score');
      result[field][level] = score;
    }
  }
  for (const field of ['music_enabled', 'sound_enabled', 'haptics_enabled']) {
    if (typeof value[field] !== 'boolean') throw new Error('Invalid settings');
    result[field] = value[field];
  }
  for (const level of result.completed_levels) result.highest_unlocked_level = Math.max(result.highest_unlocked_level, Math.min(9, level+1));
  return result;
}

export function isVkHostingOrigin(origin, appId) {
  if (typeof origin !== 'string' || !/^\d+$/.test(String(appId))) return false;
  try {
    const url = new URL(origin);
    if (url.protocol !== 'https:' || url.origin !== origin || url.port || url.username || url.password) return false;
    return new RegExp(`^(?:stage-app${appId}-[a-f0-9]{12}\\.pages\\.vk-apps\\.ru|prod-app${appId}-[a-f0-9]{12}\\.pages-ac\\.vk-apps\\.ru)$`).test(url.hostname);
  } catch { return false; }
}

export function createPaymentServer(service, allowedOrigins) {
  const origins = new Set(allowedOrigins);
  if ([...origins].some(origin => new URL(origin).protocol !== 'https:' || new URL(origin).origin !== origin)) {
    throw new Error('Allowed origins must be exact HTTPS origins');
  }
  return createServer(async (request, response) => {
    response.setHeader('Content-Type', 'application/json; charset=utf-8');
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Vary', 'Origin');
    const reply = (status, value) => { response.writeHead(status); response.end(JSON.stringify(value)); };
    const path = new URL(request.url, 'http://localhost').pathname;
    const okCallback = path.match(/^\/ok\/payments\/callback\/(test|live)$/);
    if (okCallback) {
      if (request.method !== 'GET') return reply(405, { error: 'GET required' });
      try {
        if (request.url.length > 16384) return reply(413, { error: 'Request too large' });
        const result = service.okCallback(parseForm(new URL(request.url, 'http://localhost').search.slice(1)), okCallback[1]);
        if (result !== true) response.setHeader('Invocation-error', String(result.error_code));
        return reply(200, result);
      } catch {
        response.setHeader('Invocation-error', '1001');
        return reply(200, { error_code: 1001, error_msg: 'Invalid request', error_data: null });
      }
    }
    const callback = path === '/vk/payments/callback';
    const api = ['/vk/payments/catalog', '/vk/payments/entitlements', '/vk/payments/progress'].includes(path);
    if (!callback && !api) return reply(404, { error: 'Not found' });
    if (api) {
      if (!origins.has(request.headers.origin) && !isVkHostingOrigin(request.headers.origin, service.config.appId)) return reply(403, { error: 'Origin denied' });
      response.setHeader('Access-Control-Allow-Origin', request.headers.origin);
      response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
      if (request.method === 'OPTIONS') return reply(204, null);
    }
    if (request.method !== 'POST') return reply(405, { error: 'POST required' });
    if (!(request.headers['content-type'] || '').startsWith('application/x-www-form-urlencoded')) return reply(415, { error: 'Form required' });
    try {
      const chunks = []; let size = 0;
      for await (const chunk of request) {
        size += chunk.length;
        if (size > 16384) return reply(413, { error: 'Request too large' });
        chunks.push(chunk);
      }
      const params = parseForm(Buffer.concat(chunks).toString('utf8'));
      if (callback) {
        const result = service.callback(params);
        console.info('[VK payment callback]', JSON.stringify({
          type: ['get_item', 'get_item_test', 'order_status_change', 'order_status_change_test'].includes(params.notification_type) ? params.notification_type : 'unknown',
          signature_valid: verifyCallback(params, service.config.secret),
          app_matches: params.app_id === service.config.appId,
          has_order_id: positiveId(params.order_id), has_user_id: positiveId(params.user_id),
          has_receiver_id: positiveId(params.receiver_id), product_matches: params.item === PRODUCT,
          error_code: result.error?.error_code ?? null,
          success: !!result.response
        }));
        return reply(200, result);
      }
      if (!verifyLaunch(params, service.config)) return reply(401, { error: 'Invalid VK launch signature' });
      return reply(200, path.endsWith('/progress') ? service.progress(params) : path.endsWith('/catalog') ? service.catalog(params) : service.entitlement(params));
    } catch {
      return reply(400, callback ? vkError(11, 'Invalid request') : { error: 'Invalid request' });
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const service = createPaymentService({ appId: process.env.VK_APP_ID, secret: process.env.VK_APP_SECRET,
    okAppId: process.env.OK_APP_ID, okPublicKey: process.env.OK_APP_PUBLIC_KEY,
    okSecret: process.env.OK_APP_SECRET, okMode: process.env.OK_PAYMENT_MODE,
    okPrice: process.env.OK_REMOVE_ADS_PRICE ? Number(process.env.OK_REMOVE_ADS_PRICE) : undefined,
    mode: process.env.VK_PAYMENT_MODE, price: Number(process.env.VK_REMOVE_ADS_PRICE),
    databasePath: process.env.VK_DATABASE_PATH || './data/payments.sqlite' });
  const server = createPaymentServer(service, (process.env.VK_ALLOWED_ORIGINS || '').split(',').filter(Boolean));
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  server.listen(Number(process.env.PORT || 8787), process.env.HOST || '127.0.0.1', () => console.log('VK payments server started'));
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => { service.close(); process.exit(0); }));
}
