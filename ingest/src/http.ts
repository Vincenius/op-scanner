/** Minimal JSON fetch helper with retry + polite delay (rate-limit friendly). */

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export interface FetchJsonOptions {
  headers?: Record<string, string>;
  /** Retries on network error / 429 / 5xx. */
  retries?: number;
  /** Base backoff in ms (doubled each retry). */
  backoffMs?: number;
}

export async function fetchJson<T>(
  url: string,
  options: FetchJsonOptions = {},
): Promise<T> {
  const { headers = {}, retries = 3, backoffMs = 800 } = options;
  let lastErr: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { 'user-agent': 'op-scanner-ingest', ...headers },
      });
      if (res.status === 429 || res.status >= 500) {
        throw new Error(`HTTP ${res.status} for ${url}`);
      }
      if (!res.ok) {
        throw new Error(`HTTP ${res.status} for ${url} (non-retryable)`);
      }
      return (await res.json()) as T;
    } catch (err) {
      lastErr = err;
      if (attempt < retries) {
        await sleep(backoffMs * 2 ** attempt);
      }
    }
  }
  throw new Error(
    `fetchJson failed after ${retries + 1} attempts: ${String(lastErr)}`,
  );
}
