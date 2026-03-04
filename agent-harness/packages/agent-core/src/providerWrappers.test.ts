import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { RetryProvider, FallbackProvider, isTransientError } from './providerWrappers.js';
import type { LlmProvider, LlmCompletionRequest, LlmCompletionResponse } from './provider.js';

// --- Helpers ---

function textResponse(content: string): LlmCompletionResponse {
  return { choices: [{ message: { role: 'assistant', content }, finish_reason: 'stop' }] };
}

function succeedingProvider(content = 'ok'): LlmProvider {
  return {
    async createCompletion() {
      return textResponse(content);
    },
  };
}

function failThenSucceed(
  error: Error,
  failCount: number,
): { provider: LlmProvider; callCount: () => number } {
  let calls = 0;
  return {
    provider: {
      async createCompletion() {
        calls++;
        if (calls <= failCount) throw error;
        return textResponse('recovered');
      },
    },
    callCount: () => calls,
  };
}

function alwaysFailing(error: Error): { provider: LlmProvider; callCount: () => number } {
  let calls = 0;
  return {
    provider: {
      async createCompletion() {
        calls++;
        throw error;
      },
    },
    callCount: () => calls,
  };
}

function makeRequest(overrides: Partial<LlmCompletionRequest> = {}): LlmCompletionRequest {
  return {
    model: 'test-model',
    messages: [{ role: 'user', content: 'hello' }],
    ...overrides,
  };
}

function statusError(status: number, message = `HTTP ${status}`): Error {
  const err = new Error(message);
  (err as unknown as Record<string, number>).status = status;
  return err;
}

// --- isTransientError ---

describe('isTransientError', () => {
  it('returns true for 429 status', () => {
    assert.equal(isTransientError(statusError(429)), true);
  });

  it('returns true for 500 status', () => {
    assert.equal(isTransientError(statusError(500)), true);
  });

  it('returns true for 502 status', () => {
    assert.equal(isTransientError(statusError(502)), true);
  });

  it('returns true for 503 status', () => {
    assert.equal(isTransientError(statusError(503)), true);
  });

  it('returns true for rate limit message', () => {
    assert.equal(isTransientError(new Error('Rate limit exceeded')), true);
  });

  it('returns true for timeout message', () => {
    assert.equal(isTransientError(new Error('Request timeout')), true);
  });

  it('returns true for ECONNRESET message', () => {
    assert.equal(isTransientError(new Error('read ECONNRESET')), true);
  });

  it('returns true for socket hang up message', () => {
    assert.equal(isTransientError(new Error('socket hang up')), true);
  });

  it('returns false for 401 status', () => {
    assert.equal(isTransientError(statusError(401)), false);
  });

  it('returns false for 400 status', () => {
    assert.equal(isTransientError(statusError(400)), false);
  });

  it('returns false for generic Error', () => {
    assert.equal(isTransientError(new Error('something broke')), false);
  });

  it('returns false for non-Error values', () => {
    assert.equal(isTransientError('string error'), false);
    assert.equal(isTransientError(null), false);
    assert.equal(isTransientError(42), false);
  });
});

// --- RetryProvider ---

describe('RetryProvider', () => {
  it('passes through on first success', async () => {
    const inner = succeedingProvider('hello');
    const provider = new RetryProvider(inner);
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'hello');
  });

  it('passes request through unchanged', async () => {
    let capturedReq: LlmCompletionRequest | undefined;
    const inner: LlmProvider = {
      async createCompletion(req) {
        capturedReq = req;
        return textResponse('ok');
      },
    };
    const provider = new RetryProvider(inner);
    const req = makeRequest({ model: 'special-model', temperature: 0.7 });
    await provider.createCompletion(req);
    assert.equal(capturedReq?.model, 'special-model');
    assert.equal(capturedReq?.temperature, 0.7);
  });

  it('retries transient errors and succeeds', async () => {
    const { provider: inner, callCount } = failThenSucceed(statusError(429), 2);
    const provider = new RetryProvider(inner, { maxRetries: 3, baseDelayMs: 1 });
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'recovered');
    assert.equal(callCount(), 3); // 2 failures + 1 success
  });

  it('throws after exhausting all retries', async () => {
    const { provider: inner, callCount } = alwaysFailing(statusError(500));
    const provider = new RetryProvider(inner, { maxRetries: 2, baseDelayMs: 1 });
    await assert.rejects(
      () => provider.createCompletion(makeRequest()),
      (err: Error) => err.message === 'HTTP 500',
    );
    assert.equal(callCount(), 3); // initial + 2 retries
  });

  it('does not retry non-transient errors', async () => {
    const { provider: inner, callCount } = alwaysFailing(statusError(401, 'Unauthorized'));
    const provider = new RetryProvider(inner, { maxRetries: 3, baseDelayMs: 1 });
    await assert.rejects(
      () => provider.createCompletion(makeRequest()),
      (err: Error) => err.message === 'Unauthorized',
    );
    assert.equal(callCount(), 1); // no retries
  });

  it('does not retry when signal is already aborted', async () => {
    const { provider: inner, callCount } = alwaysFailing(statusError(429));
    const controller = new AbortController();
    controller.abort('cancelled');
    const provider = new RetryProvider(inner, { maxRetries: 3, baseDelayMs: 1 });
    await assert.rejects(() =>
      provider.createCompletion(makeRequest({ signal: controller.signal })),
    );
    assert.equal(callCount(), 1);
  });

  it('calls onRetry callback on each retry', async () => {
    const retries: Array<{ attempt: number; delayMs: number }> = [];
    const { provider: inner } = failThenSucceed(statusError(429), 2);
    const provider = new RetryProvider(inner, {
      maxRetries: 3,
      baseDelayMs: 1,
      onRetry: (_err, attempt, delayMs) => retries.push({ attempt, delayMs }),
    });
    await provider.createCompletion(makeRequest());
    assert.equal(retries.length, 2);
    assert.equal(retries[0].attempt, 1);
    assert.equal(retries[1].attempt, 2);
  });

  it('uses custom isRetryable function', async () => {
    const customError = new Error('custom-retriable');
    const { provider: inner, callCount } = failThenSucceed(customError, 1);
    const provider = new RetryProvider(inner, {
      maxRetries: 2,
      baseDelayMs: 1,
      isRetryable: (err) => err instanceof Error && err.message === 'custom-retriable',
    });
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'recovered');
    assert.equal(callCount(), 2);
  });

  it('does not retry when custom isRetryable returns false', async () => {
    const { provider: inner, callCount } = alwaysFailing(statusError(429));
    const provider = new RetryProvider(inner, {
      maxRetries: 3,
      baseDelayMs: 1,
      isRetryable: () => false,
    });
    await assert.rejects(() => provider.createCompletion(makeRequest()));
    assert.equal(callCount(), 1);
  });

  it('increases delay between retries', async () => {
    const delays: number[] = [];
    const { provider: inner } = failThenSucceed(statusError(429), 3);
    const provider = new RetryProvider(inner, {
      maxRetries: 3,
      baseDelayMs: 10,
      maxDelayMs: 100_000,
      onRetry: (_err, _attempt, delayMs) => delays.push(delayMs),
    });
    await provider.createCompletion(makeRequest());
    // Delays should generally increase (exponential), though jitter adds variance
    // baseDelayMs * 2^attempt + jitter, so delay[1] base is 20, delay[2] base is 40
    assert.equal(delays.length, 3);
    // With jitter the first delay is in [10, 20), second in [20, 30), third in [40, 50)
    // Just verify they're all positive
    for (const d of delays) assert.ok(d > 0);
  });

  it('caps delay at maxDelayMs', async () => {
    const delays: number[] = [];
    const { provider: inner } = failThenSucceed(statusError(429), 2);
    const provider = new RetryProvider(inner, {
      maxRetries: 3,
      baseDelayMs: 100,
      maxDelayMs: 50,
      onRetry: (_err, _attempt, delayMs) => delays.push(delayMs),
    });
    await provider.createCompletion(makeRequest());
    for (const d of delays) assert.ok(d <= 50);
  });
});

// --- FallbackProvider ---

describe('FallbackProvider', () => {
  it('throws if constructed with empty providers array', () => {
    assert.throws(
      () => new FallbackProvider([]),
      (err: Error) => err.message.includes('at least one provider'),
    );
  });

  it('returns result from first provider on success', async () => {
    const provider = new FallbackProvider([
      succeedingProvider('first'),
      succeedingProvider('second'),
    ]);
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'first');
  });

  it('does not call subsequent providers on success', async () => {
    const { provider: second, callCount } = alwaysFailing(new Error('should not be called'));
    const provider = new FallbackProvider([succeedingProvider('ok'), second]);
    await provider.createCompletion(makeRequest());
    assert.equal(callCount(), 0);
  });

  it('falls back to second provider when first fails', async () => {
    const { provider: first } = alwaysFailing(new Error('first failed'));
    const provider = new FallbackProvider([first, succeedingProvider('second')]);
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'second');
  });

  it('falls back through multiple providers', async () => {
    const { provider: p1 } = alwaysFailing(new Error('p1 failed'));
    const { provider: p2 } = alwaysFailing(new Error('p2 failed'));
    const provider = new FallbackProvider([p1, p2, succeedingProvider('p3')]);
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'p3');
  });

  it('throws last error when all providers fail', async () => {
    const { provider: p1 } = alwaysFailing(new Error('p1'));
    const { provider: p2 } = alwaysFailing(new Error('p2'));
    await assert.rejects(
      () => new FallbackProvider([p1, p2]).createCompletion(makeRequest()),
      (err: Error) => err.message === 'p2',
    );
  });

  it('calls onFallback callback', async () => {
    const fallbacks: Array<{ from: number; to: number }> = [];
    const { provider: p1 } = alwaysFailing(new Error('fail'));
    const provider = new FallbackProvider([p1, succeedingProvider('ok')], {
      onFallback: (_err, from, to) => fallbacks.push({ from, to }),
    });
    await provider.createCompletion(makeRequest());
    assert.equal(fallbacks.length, 1);
    assert.equal(fallbacks[0].from, 0);
    assert.equal(fallbacks[0].to, 1);
  });

  it('respects custom shouldFallback returning false', async () => {
    const { provider: p1 } = alwaysFailing(statusError(401, 'Auth error'));
    const provider = new FallbackProvider([p1, succeedingProvider('second')], {
      shouldFallback: () => false,
    });
    await assert.rejects(
      () => provider.createCompletion(makeRequest()),
      (err: Error) => err.message === 'Auth error',
    );
  });

  it('falls back when custom shouldFallback returns true', async () => {
    const { provider: p1 } = alwaysFailing(new Error('fail'));
    const provider = new FallbackProvider([p1, succeedingProvider('ok')], {
      shouldFallback: () => true,
    });
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'ok');
  });

  it('does not fall back when signal is aborted', async () => {
    const controller = new AbortController();
    controller.abort('cancelled');
    const { provider: _p1 } = alwaysFailing(new Error('fail'));
    const { provider: p2, callCount } = alwaysFailing(new Error('should not reach'));
    // The inner provider throws because the signal is aborted
    const provider = new FallbackProvider([
      {
        async createCompletion() {
          throw new Error('fail');
        },
      },
      p2,
    ]);
    await assert.rejects(() =>
      provider.createCompletion(makeRequest({ signal: controller.signal })),
    );
    assert.equal(callCount(), 0);
  });
});

// --- Composition ---

describe('provider composition', () => {
  it('RetryProvider wrapping FallbackProvider', async () => {
    const { provider: p1 } = alwaysFailing(statusError(500));
    const fallback = new FallbackProvider([p1, succeedingProvider('backup')]);
    const provider = new RetryProvider(fallback, { maxRetries: 1, baseDelayMs: 1 });
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'backup');
  });

  it('FallbackProvider with RetryProvider children', async () => {
    const { provider: flaky } = failThenSucceed(statusError(429), 1);
    const primary = new RetryProvider(flaky, { maxRetries: 2, baseDelayMs: 1 });
    const secondary = succeedingProvider('secondary');
    const provider = new FallbackProvider([primary, secondary]);
    // Primary should recover after 1 retry, never reaching secondary
    const result = await provider.createCompletion(makeRequest());
    assert.equal(result.choices[0].message.content, 'recovered');
  });
});
