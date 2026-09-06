import { test } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'crypto';
import { queryTwoBits, updateTwoBits, _resetJwtCacheForTest } from './device_check.js';

// A real EC private key is required for jsonwebtoken's ES256 signer to run
// at all (it validates key shape before ever making a network call) — this
// one is generated fresh per test run, not Apple's real key, and is never
// used against Apple's actual servers since _fetch is stubbed below.
const { privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const testPrivateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' });

function fakeFetch(status, bodyText) {
  const calls = [];
  const fn = async (url, init) => {
    calls.push({ url, init });
    return { ok: status >= 200 && status < 300, status, text: async () => bodyText };
  };
  fn.calls = calls;
  return fn;
}

test('D-059: query_two_bits treats an empty 200 body as never-set, not an '
    + 'error — this is Apple\'s documented response for a device with no '
    + 'recorded state', async () => {
  _resetJwtCacheForTest();
  const fetch = fakeFetch(200, '');
  const result = await queryTwoBits('device-token', { privateKeyPem: testPrivateKeyPem, _fetch: fetch });
  assert.deepEqual(result, { bit0: false, bit1: false });
});

test('D-059: query_two_bits parses a real bit response', async () => {
  _resetJwtCacheForTest();
  const fetch = fakeFetch(200, JSON.stringify({ bit0: true, bit1: false, last_update_time: '2026-06' }));
  const result = await queryTwoBits('device-token', { privateKeyPem: testPrivateKeyPem, _fetch: fetch });
  assert.deepEqual(result, { bit0: true, bit1: false });
});

test('D-059: query_two_bits routes to the development endpoint when asked', async () => {
  _resetJwtCacheForTest();
  const fetch = fakeFetch(200, '');
  await queryTwoBits('device-token', { privateKeyPem: testPrivateKeyPem, isDevelopmentBuild: true, _fetch: fetch });
  assert.match(fetch.calls[0].url, /^https:\/\/api\.development\.devicecheck\.apple\.com/);
});

test('D-059: query_two_bits routes to production by default', async () => {
  _resetJwtCacheForTest();
  const fetch = fakeFetch(200, '');
  await queryTwoBits('device-token', { privateKeyPem: testPrivateKeyPem, _fetch: fetch });
  assert.match(fetch.calls[0].url, /^https:\/\/api\.devicecheck\.apple\.com/);
  assert.match(fetch.calls[0].init.headers.Authorization, /^Bearer /);
});

test('D-059: query_two_bits throws with status and body on a non-2xx response', async () => {
  _resetJwtCacheForTest();
  const fetch = fakeFetch(400, 'bad device token');
  await assert.rejects(
    () => queryTwoBits('device-token', { privateKeyPem: testPrivateKeyPem, _fetch: fetch }),
    /400.*bad device token/,
  );
});

test('D-059: update_two_bits sends the requested bits', async () => {
  _resetJwtCacheForTest();
  const fetch = fakeFetch(200, '');
  await updateTwoBits('device-token', { bit0: true, bit1: false, privateKeyPem: testPrivateKeyPem, _fetch: fetch });
  const body = JSON.parse(fetch.calls[0].init.body);
  assert.equal(body.bit0, true);
  assert.equal(body.bit1, false);
  assert.equal(body.device_token, 'device-token');
});
