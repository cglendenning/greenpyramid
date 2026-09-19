/**
 * Shared seeded PRNG for sandbox-only synthetic data generation (D-162, D-173).
 * Same seed always produces the same sequence; never used for anything
 * security-sensitive.
 */
export function seededRandom(seed) {
  let value = seed >>> 0;
  return () => {
    value = (1664525 * value + 1013904223) >>> 0;
    return value / 4294967296;
  };
}
