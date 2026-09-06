// D-059: Apple's sanctioned per-device trial-abuse mechanism — App Review
// Guideline 3.1.1 names DeviceCheck specifically for managing trial
// duration. Apple stores two bits per device, server-side, surviving app
// deletion and reinstall; Green Pyramid persists no iOS device identifier
// of its own. This module only signs the required JWT and calls Apple's
// query/update endpoints — bit0 is the one fact this app cares about:
// "has this device already consumed its trial."
import jwt from 'jsonwebtoken';
import crypto from 'crypto';

export const DEVICECHECK_KEY_ID = '9J7643YB62';
export const DEVICECHECK_TEAM_ID = 'MCALPSQ5P5';

const PROD_BASE = 'https://api.devicecheck.apple.com/v1';
// Apps run from Xcode in debug carry a development provisioning profile and
// must hit this endpoint instead — TestFlight and App Store builds carry a
// distribution profile and use the production endpoint above. Flagged: this
// mapping (kDebugMode -> development) is Apple's documented rule but hasn't
// been confirmed against a live Xcode debug run yet; verify with a real
// device before relying on it for anything but production traffic.
const DEV_BASE = 'https://api.development.devicecheck.apple.com/v1';

let cachedJwt = null;
let cachedJwtExpiresAt = 0;

// Apple's guidance is to reuse a signed token rather than mint one per
// request. Regenerated every 50 minutes here — short enough that a signing
// problem (e.g. a rotated/invalid key) surfaces within the hour rather than
// staying silently stale.
function signedJwt(privateKeyPem, _now = Date.now()) {
  if (cachedJwt && _now < cachedJwtExpiresAt) return cachedJwt;
  cachedJwt = jwt.sign(
    { iss: DEVICECHECK_TEAM_ID, iat: Math.floor(_now / 1000) },
    privateKeyPem,
    { algorithm: 'ES256', keyid: DEVICECHECK_KEY_ID },
  );
  cachedJwtExpiresAt = _now + 50 * 60 * 1000;
  return cachedJwt;
}

// Exported so tests can reset the module-level cache between cases.
export function _resetJwtCacheForTest() {
  cachedJwt = null;
  cachedJwtExpiresAt = 0;
}

async function post(path, body, { privateKeyPem, isDevelopmentBuild, _fetch = fetch }) {
  const base = isDevelopmentBuild ? DEV_BASE : PROD_BASE;
  const token = signedJwt(privateKeyPem);
  return _fetch(`${base}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
}

// { bit0, bit1 }, both false if Apple has never recorded state for this
// device — query_two_bits responds 200 with an empty body in that case
// (documented Apple behavior), not 404, so an empty body is not an error.
export async function queryTwoBits(deviceToken, { privateKeyPem, isDevelopmentBuild = false, _fetch } = {}) {
  const res = await post('/query_two_bits', {
    device_token: deviceToken,
    transaction_id: crypto.randomUUID(),
    timestamp: Date.now(),
  }, { privateKeyPem, isDevelopmentBuild, _fetch });

  if (!res.ok) throw new Error(`DeviceCheck query_two_bits failed: ${res.status} ${await res.text()}`);
  const text = await res.text();
  if (!text.trim()) return { bit0: false, bit1: false };
  const data = JSON.parse(text);
  return { bit0: !!data.bit0, bit1: !!data.bit1 };
}

export async function updateTwoBits(deviceToken, { bit0, bit1, privateKeyPem, isDevelopmentBuild = false, _fetch } = {}) {
  const res = await post('/update_two_bits', {
    device_token: deviceToken,
    transaction_id: crypto.randomUUID(),
    timestamp: Date.now(),
    bit0,
    bit1,
  }, { privateKeyPem, isDevelopmentBuild, _fetch });

  if (!res.ok) throw new Error(`DeviceCheck update_two_bits failed: ${res.status} ${await res.text()}`);
}
