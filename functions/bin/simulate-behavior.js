#!/usr/bin/env node
import { runSimulation } from '../lib/behavioral_simulator.js';

const args = new Map(process.argv.slice(2).map((arg) => {
  const [key, value] = arg.split('=', 2);
  return [key, value];
}));

try {
  const report = runSimulation({
    projectId: args.get('--project') || 'greenpyramid-sandbox',
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
