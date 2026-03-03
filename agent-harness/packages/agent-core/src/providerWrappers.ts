import type { LlmProvider, LlmCompletionRequest, LlmCompletionResponse } from './provider.js';

// --- Error Classification ---

/** Determines if an error is transient (retriable): 429, 500, 502, 503, timeouts, connection resets. */
export function isTransientError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  if ('status' in error) {
    const status = (error as { status: number }).status;
    if (status === 429 || status === 500 || status === 502 || status === 503) return true;
  }
  const msg = error.message.toLowerCase();
  return (
    msg.includes('rate limit') ||
    msg.includes('429') ||
    msg.includes('500') ||
    msg.includes('502') ||
    msg.includes('503') ||
    msg.includes('timeout') ||
    msg.includes('econnreset') ||
    msg.includes('socket hang up')
  );
}

// --- RetryProvider ---

export interface RetryProviderOptions {
  /** Maximum number of retries (not counting the initial attempt). Default: 3. */
  maxRetries?: number;
  /** Base delay in ms for exponential backoff. Default: 1000. */
  baseDelayMs?: number;
  /** Maximum delay in ms. Default: 30000. */
  maxDelayMs?: number;
  /** Custom function to determine if an error should be retried. Overrides default transient check. */
  isRetryable?: (error: unknown) => boolean;
  /** Called on each retry attempt for logging/observability. */
  onRetry?: (error: unknown, attempt: number, delayMs: number) => void;
}

/**
 * Wraps an LlmProvider with automatic retry on transient errors.
 * Uses exponential backoff with jitter.
 */
export class RetryProvider implements LlmProvider {
  private readonly inner: LlmProvider;
  private readonly maxRetries: number;
  private readonly baseDelayMs: number;
  private readonly maxDelayMs: number;
  private readonly isRetryable: (error: unknown) => boolean;
  private readonly onRetry?: (error: unknown, attempt: number, delayMs: number) => void;

  constructor(provider: LlmProvider, options: RetryProviderOptions = {}) {
    this.inner = provider;
    this.maxRetries = options.maxRetries ?? 3;
    this.baseDelayMs = options.baseDelayMs ?? 1000;
    this.maxDelayMs = options.maxDelayMs ?? 30_000;
    this.isRetryable = options.isRetryable ?? isTransientError;
    this.onRetry = options.onRetry;
  }

  async createCompletion(request: LlmCompletionRequest): Promise<LlmCompletionResponse> {
    let lastError: unknown;

    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        return await this.inner.createCompletion(request);
      } catch (error) {
        lastError = error;
        if (request.signal?.aborted) throw error;
        if (attempt >= this.maxRetries || !this.isRetryable(error)) throw error;

        const exponentialDelay = this.baseDelayMs * Math.pow(2, attempt);
        const jitter = Math.random() * this.baseDelayMs;
        const delayMs = Math.min(exponentialDelay + jitter, this.maxDelayMs);

        this.onRetry?.(error, attempt + 1, delayMs);
        await this.sleep(delayMs, request.signal);
      }
    }

    throw lastError;
  }

  private sleep(ms: number, signal?: AbortSignal): Promise<void> {
    return new Promise((resolve, reject) => {
      if (signal?.aborted) {
        reject(signal.reason ?? new Error('The operation was aborted'));
        return;
      }
      const timer = setTimeout(resolve, ms);
      signal?.addEventListener(
        'abort',
        () => {
          clearTimeout(timer);
          reject(signal.reason ?? new Error('The operation was aborted'));
        },
        { once: true },
      );
    });
  }
}

// --- FallbackProvider ---

export interface FallbackProviderOptions {
  /** Custom function to determine if an error should trigger fallback. Default: all errors. */
  shouldFallback?: (error: unknown) => boolean;
  /** Called when falling back to the next provider, for logging/observability. */
  onFallback?: (error: unknown, failedIndex: number, nextIndex: number) => void;
}

/**
 * Wraps multiple LlmProviders, trying each in order until one succeeds.
 * If all fail, throws the last error.
 */
export class FallbackProvider implements LlmProvider {
  private readonly providers: LlmProvider[];
  private readonly shouldFallback: (error: unknown) => boolean;
  private readonly onFallback?: (error: unknown, failedIndex: number, nextIndex: number) => void;

  constructor(providers: LlmProvider[], options: FallbackProviderOptions = {}) {
    if (providers.length === 0) {
      throw new Error('FallbackProvider requires at least one provider');
    }
    this.providers = providers;
    this.shouldFallback = options.shouldFallback ?? (() => true);
    this.onFallback = options.onFallback;
  }

  async createCompletion(request: LlmCompletionRequest): Promise<LlmCompletionResponse> {
    let lastError: unknown;

    for (let i = 0; i < this.providers.length; i++) {
      try {
        return await this.providers[i].createCompletion(request);
      } catch (error) {
        lastError = error;
        if (request.signal?.aborted) throw error;
        const hasNext = i < this.providers.length - 1;
        if (!hasNext || !this.shouldFallback(error)) throw error;
        this.onFallback?.(error, i, i + 1);
      }
    }

    throw lastError;
  }
}
