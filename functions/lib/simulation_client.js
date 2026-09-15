const DEFAULT_ENDPOINT = 'https://us-central1-life-ops.cloudfunctions.net/api/adminSimulation';

/** D-162/D-165: transport shared by the CLI contract and the admin endpoint. */
export async function requestSimulation({
  endpoint = DEFAULT_ENDPOINT,
  token = process.env.FIREBASE_ID_TOKEN,
  months = 6,
  seed = 1,
  scenarios,
  failureMode = 'default',
  fetchImpl = globalThis.fetch,
} = {}) {
  if (!token) throw new Error('admin_token_required');
  if (typeof fetchImpl !== 'function') throw new Error('fetch_unavailable');
  const body = { months, seed, failureMode };
  if (scenarios !== undefined) body.scenarios = scenarios;
  const response = await fetchImpl(endpoint, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  let payload;
  try {
    payload = await response.json();
  } catch {
    throw new Error(`admin_simulation_http_${response.status}`);
  }
  if (!response.ok) throw new Error(payload?.error || `admin_simulation_http_${response.status}`);
  return payload;
}
