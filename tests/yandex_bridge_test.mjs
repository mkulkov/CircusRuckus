import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const html = fs.readFileSync(new URL('../web/portrait_shell.html', import.meta.url), 'utf8');
const match = html.match(/\/\/ A small host API[\s\S]*?<\/script>/);
assert.ok(match, 'platform bridge script exists');
const source = match[0].replace(/<\/script>$/, '');

let initCount = 0;
let gameplayStarts = 0;
let gameplayStops = 0;
let bannerShows = 0;
let cloudWrite = null;
const listeners = new Map();
const player = {
	getData: async () => ({ clown_smash_save: { save_version: 1, highest_unlocked_level: 2 } }),
	setData: async (data, flush) => { cloudWrite = { data, flush }; },
};
const ysdk = {
	environment: { i18n: { lang: 'en' } },
	features: {
		LoadingAPI: { ready() {} },
		GameplayAPI: {
			start() { gameplayStarts += 1; },
			stop() { gameplayStops += 1; },
		},
	},
	on(name, callback) { listeners.set(name, callback); },
	getPlayer: async () => player,
	adv: {
		getBannerAdvStatus: async () => ({ stickyAdvIsShowing: false }),
		showBannerAdv: async () => { bannerShows += 1; return { stickyAdvIsShowing: true }; },
		hideBannerAdv: async () => ({ stickyAdvIsShowing: false }),
		showFullscreenAdv() {},
	},
	payments: {
		getPurchases: async () => [],
		getCatalog: async () => [{
			id: 'remove_ads',
			price: '49 YAN',
			getPriceCurrencyImage: (size) => `https://example.test/currency-${size}.png`,
		}],
		purchase: async ({ id }) => ({ productID: id }),
	},
};

const context = vm.createContext({
	window: {},
	YaGames: { init: async () => { initCount += 1; return ysdk; } },
	console, URLSearchParams,
	JSON,
	Promise,
});
vm.runInContext(source, context);
const bridge = context.window.ClownSmashPlatform;
const flush = () => new Promise((resolve) => setImmediate(resolve));

let initialized = null;
let locale = null;
bridge.initialize((value) => { initialized = JSON.parse(value); });
bridge.getLocale((value) => { locale = value; });
await flush();
assert.equal(initCount, 1, 'SDK is initialized once');
assert.equal(initialized.platform, 'yandex');
assert.equal(locale, 'en');

let pauses = 0;
let resumes = 0;
bridge.subscribeLifecycle(() => { pauses += 1; }, () => { resumes += 1; });
bridge.setGameplayActive(true);
await flush();
assert.equal(gameplayStarts, 1);
listeners.get('game_api_pause')();
listeners.get('game_api_resume')();
assert.equal(pauses, 1);
assert.equal(resumes, 1);
bridge.setGameplayActive(false);
await flush();
assert.equal(gameplayStops, 1);

let bannerStatus = null;
bridge.setBannerVisible(true, (value) => { bannerStatus = JSON.parse(value); });
await flush();
await flush();
assert.equal(bannerShows, 1);
assert.equal(bannerStatus.visible, true);

let cloudLoad = null;
bridge.loadCloudSave((value) => { cloudLoad = JSON.parse(value); });
await flush();
await flush();
assert.equal(cloudLoad.data.highest_unlocked_level, 2);

let cloudSave = null;
bridge.saveCloudSave(JSON.stringify({ save_version: 1, highest_unlocked_level: 3 }), (value) => { cloudSave = JSON.parse(value); });
await flush();
await flush();
assert.equal(cloudSave.success, true);
assert.equal(cloudWrite.flush, true);
assert.equal(cloudWrite.data.clown_smash_save.highest_unlocked_level, 3);

let productInfo = null;
bridge.loadProductCatalog((value) => { productInfo = JSON.parse(value); });
await flush();
assert.equal(productInfo.product_id, 'remove_ads');
assert.equal(productInfo.price, '49 YAN');
assert.equal(productInfo.currency_icon_url, 'https://example.test/currency-small.png');

let purchaseResult = null;
bridge.purchase('remove_ads', (value) => { purchaseResult = JSON.parse(value); });
await flush();
assert.equal(purchaseResult.success, true);
assert.equal(purchaseResult.product_id, 'remove_ads');

console.log('YANDEX BRIDGE TEST: PASS');
