'use strict';

const fs = require('fs');
const path = require('path');
const Configstore = require('configstore');
const FormData = require('form-data');
const fetch = require('node-fetch');

const APP_ID = 54768735;
const API_VERSION = '5.131';
const CLI_VERSION = 2;
const DEPLOY_PACKAGE = '@vkontakte/vk-miniapps-deploy';
const BUNDLE_PATH = path.join(__dirname, 'build.zip');
const vault = new Configstore(DEPLOY_PACKAGE, {});

function timeoutSignal(milliseconds) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), milliseconds);
  return { signal: controller.signal, cancel: () => clearTimeout(timer) };
}

async function vkApi(method, params, accessToken) {
  const query = new URLSearchParams({
    ...params,
    v: API_VERSION,
    cli_version: String(CLI_VERSION),
    access_token: accessToken,
  });
  const timeout = timeoutSignal(30000);
  try {
    const response = await fetch(`https://api.vk.ru/method/${method}?${query}`, {
      signal: timeout.signal,
    });
    const payload = await response.json();
    if (payload.error) {
      const error = new Error(payload.error.error_msg || 'VK API error');
      error.code = payload.error.error_code;
      throw error;
    }
    return payload.response;
  } finally {
    timeout.cancel();
  }
}

function describeUploadResponse(payload) {
  const result = {
    type: Array.isArray(payload) ? 'array' : typeof payload,
    keys: payload && typeof payload === 'object' ? Object.keys(payload).sort() : [],
  };

  if (!payload || typeof payload !== 'object') {
    return result;
  }

  for (const [key, value] of Object.entries(payload)) {
    if (key === '_sig' || key === 'sig' || key === 'access_token') {
      result[key] = value ? `[present, length=${String(value).length}]` : '[missing]';
    } else if (key === 'file' || key === 'upload_response') {
      result[key] = value ? `[present, length=${String(value).length}]` : '[missing]';
    } else if (typeof value === 'string' && value.length > 300) {
      result[key] = `[string, length=${value.length}]`;
    } else {
      result[key] = value;
    }
  }

  return result;
}

async function main() {
  const accessToken = process.env.MINI_APPS_ACCESS_TOKEN || vault.get('access_token');
  if (!accessToken) {
    throw new Error('Сохранённый токен загрузчика не найден. Повторно запускать вход пока не нужно.');
  }
  if (!fs.existsSync(BUNDLE_PATH)) {
    throw new Error(`Архив не найден: ${BUNDLE_PATH}`);
  }

  const params = {
    app_id: String(APP_ID),
    environment: '3',
    update_prod: '1',
    update_dev: '1',
    endpoint_mobile: 'index.html',
    endpoint_mvk: 'index.html',
    endpoint_web: 'index.html',
  };

  const uploadServer = await vkApi('apps.getGoHostingUploadServer', params, accessToken);
  if (!uploadServer || !uploadServer.upload_url) {
    throw new Error('VK API не вернул адрес сервера загрузки.');
  }

  const form = new FormData();
  form.append('file', fs.createReadStream(BUNDLE_PATH), {
    contentType: 'application/zip',
    filename: 'build.zip',
    knownLength: fs.statSync(BUNDLE_PATH).size,
  });
  const uploadTimeout = timeoutSignal(60000);
  let uploadResponse;
  try {
    const response = await fetch(uploadServer.upload_url, {
      method: 'POST',
      headers: form.getHeaders(),
      body: form,
      signal: uploadTimeout.signal,
    });
    const body = await response.text();
    console.log(JSON.stringify({
      stage: 'upload',
      http_status: response.status,
      content_type: response.headers.get('content-type'),
      response_length: body.length,
    }, null, 2));
    try {
      uploadResponse = JSON.parse(body);
    } catch (_error) {
      console.log(JSON.stringify({ body_preview: body.slice(0, 300) }, null, 2));
      throw new Error('Сервер загрузки вернул не JSON.');
    }
  } finally {
    uploadTimeout.cancel();
  }

  console.log(JSON.stringify({
    stage: 'upload_response',
    response: describeUploadResponse(uploadResponse),
  }, null, 2));

  try {
    const task = await vkApi('apps.createGoHostingTask', {
      ...params,
      upload_response: Buffer.from(JSON.stringify(uploadResponse)).toString('base64'),
    }, accessToken);
    console.log(JSON.stringify({
      stage: 'create_task',
      ok: true,
      version: task && task.version,
      keys: task && typeof task === 'object' ? Object.keys(task).sort() : [],
    }, null, 2));
  } catch (error) {
    console.log(JSON.stringify({
      stage: 'create_task',
      ok: false,
      error_code: error.code,
      error_message: error.message,
    }, null, 2));
    process.exitCode = 2;
  }
}

main().catch((error) => {
  console.error(JSON.stringify({
    stage: 'diagnostic',
    ok: false,
    error_name: error.name,
    error_message: error.message,
  }, null, 2));
  process.exitCode = 1;
});
