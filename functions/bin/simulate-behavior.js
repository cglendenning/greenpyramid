#!/usr/bin/env node
// D-162-AC-05: this CLI only transports requests to the protected endpoint.
import { requestSimulation } from '../lib/simulation_client.js';

const args = new Map(process.argv.slice(2).map((arg) => {
  const [key, value] = arg.split('=', 2);
  return [key, value];
}));

try {
  if (args.has('--help')) {
    process.stdout.write('Usage: FIREBASE_ID_TOKEN=... node functions/bin/simulate-behavior.js [--endpoint=URL] [--months=N] [--seed=N] [--scenarios=a,b] [--failure-mode=default|none]\nOutput: JSON from the shared adminSimulation endpoint, including aggregate and per-scenario selectedTypes counts.\n');
    process.exit(0);
  }
  const report = await requestSimulation({
    endpoint: args.get('--endpoint') || 'https://us-central1-life-ops.cloudfunctions.net/api/adminSimulation',
    token: process.env.FIREBASE_ID_TOKEN,
    months: Number(args.get('--months') || 6),
    seed: Number(args.get('--seed') || 1),
    scenarios: (args.get('--scenarios') || undefined)?.split(',').filter(Boolean),
    failureMode: args.get('--failure-mode') || 'default',
  });
  process.stdout.write(`${JSON.stringify(report)}\n`);
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
}
