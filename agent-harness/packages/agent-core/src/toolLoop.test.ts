import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { executeToolLoop, type ToolLoopHooks } from './toolLoop.js';
import type { LlmProvider, LlmCompletionRequest, LlmCompletionResponse } from './provider.js';
import type { ToolDefinition, ToolHandler, ToolHandlerResult } from './types.js';

// --- Test Helpers ---

function createMockProvider(responses: LlmCompletionResponse[]) {
  const queue = [...responses];
  const requests: LlmCompletionRequest[] = [];
  return {
    provider: {
      async createCompletion(req: LlmCompletionRequest) {
        requests.push(req);
        const next = queue.shift();
        if (!next) throw new Error('No more mock responses');
        return next;
      },
    } as LlmProvider,
    requests,
  };
}

function textResponse(content: string): LlmCompletionResponse {
  return { choices: [{ message: { role: 'assistant', content }, finish_reason: 'stop' }] };
}

function toolCallResponse(calls: Array<{ id: string; name: string; args: Record<string, unknown> }>): LlmCompletionResponse {
  return {
    choices: [{
      message: {
        role: 'assistant',
        content: null,
        tool_calls: calls.map(c => ({
          id: c.id,
          type: 'function' as const,
          function: { name: c.name, arguments: JSON.stringify(c.args) },
        })),
      },
      finish_reason: 'tool_calls',
    }],
  };
}

const echoTool: ToolDefinition = {
  type: 'function',
  function: { name: 'echo', description: 'Echoes input', parameters: { type: 'object', properties: { text: { type: 'string' } } } },
};

const echoHandler: ToolHandler = async (args) => ({
  toolResponse: { status: 'success', message: String(args.text ?? 'no input') },
});

// --- Tests ---

describe('executeToolLoop', () => {
  describe('basic completion', () => {
    it('returns text response when no tools provided', async () => {
      const { provider } = createMockProvider([textResponse('Hello!')]);
      const result = await executeToolLoop({
        provider, model: 'test', tools: [], toolHandlers: {},
        messages: [{ role: 'user', content: 'Hi' }],
      });
      assert.equal(result.responseMessage.content, 'Hello!');
      assert.equal(result.iterations, 0);
      assert.deepEqual(result.actions, []);
    });

    it('returns text response when LLM does not call tools', async () => {
      const { provider } = createMockProvider([textResponse('Just text')]);
      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'Hi' }],
      });
      assert.equal(result.responseMessage.content, 'Just text');
      assert.equal(result.iterations, 0);
    });
  });

  describe('single tool call', () => {
    it('executes a tool call and returns follow-up response', async () => {
      const { provider, requests } = createMockProvider([
        toolCallResponse([{ id: 'call-1', name: 'echo', args: { text: 'hello' } }]),
        textResponse('Done'),
      ]);

      const handlerCalls: Record<string, unknown>[] = [];
      const handler: ToolHandler = async (args) => {
        handlerCalls.push(args);
        return { toolResponse: { status: 'success', message: 'echoed' } };
      };

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: handler },
        messages: [{ role: 'user', content: 'call echo' }],
      });

      assert.equal(result.responseMessage.content, 'Done');
      assert.equal(result.iterations, 1);
      assert.equal(handlerCalls.length, 1);
      assert.equal(handlerCalls[0].text, 'hello');
    });

    it('collects actions from tool handler results', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'call-1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      const handler: ToolHandler = async () => ({
        toolResponse: { status: 'success', message: 'ok' },
        action: { type: 'test_action', payload: { key: 'value' } },
      });

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: handler },
        messages: [{ role: 'user', content: 'go' }],
      });

      assert.equal(result.actions.length, 1);
      assert.equal(result.actions[0].type, 'test_action');
    });

    it('collects multiple actions from array action field', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'call-1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      const handler: ToolHandler = async () => ({
        toolResponse: { status: 'success', message: 'ok' },
        action: [
          { type: 'action_a', payload: {} },
          { type: 'action_b', payload: {} },
        ],
      });

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: handler },
        messages: [{ role: 'user', content: 'go' }],
      });

      assert.equal(result.actions.length, 2);
    });
  });

  describe('multiple iterations', () => {
    it('handles multi-step tool calling', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: { text: 'step1' } }]),
        toolCallResponse([{ id: 'c2', name: 'echo', args: { text: 'step2' } }]),
        textResponse('All done'),
      ]);

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'multi-step' }],
      });

      assert.equal(result.iterations, 2);
      assert.equal(result.responseMessage.content, 'All done');
    });

    it('stops at maxIterations', async () => {
      const { provider, requests } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        toolCallResponse([{ id: 'c2', name: 'echo', args: {} }]),
        textResponse('Forced stop'),
      ]);

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'go' }],
        maxIterations: 2,
      });

      assert.equal(result.iterations, 2);
      // The follow-up call at maxIterations should have no tools (forces text response)
      const lastReq = requests[requests.length - 1];
      assert.equal(lastReq.tools, undefined);
    });
  });

  describe('tool call error handling', () => {
    it('returns error when tool is not in allowedToolNames', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'go' }],
        allowedToolNames: new Set(['other_tool']),
      });

      assert.equal(result.iterations, 1);
    });

    it('returns error for invalid JSON in tool arguments', async () => {
      const badResponse: LlmCompletionResponse = {
        choices: [{
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [{
              id: 'c1',
              type: 'function',
              function: { name: 'echo', arguments: 'not valid json' },
            }],
          },
          finish_reason: 'tool_calls',
        }],
      };

      const { provider } = createMockProvider([badResponse, textResponse('Done')]);
      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'go' }],
      });

      assert.equal(result.iterations, 1);
    });

    it('returns error when no handler registered for tool', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'unknown_tool', args: {} }]),
        textResponse('Done'),
      ]);

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'go' }],
      });

      assert.equal(result.iterations, 1);
    });

    it('catches handler errors and returns error response', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      const throwingHandler: ToolHandler = async () => { throw new Error('handler boom'); };

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: throwingHandler },
        messages: [{ role: 'user', content: 'go' }],
      });

      // Loop should continue, not crash
      assert.equal(result.iterations, 1);
      assert.equal(result.responseMessage.content, 'Done');
    });
  });

  describe('JSON stringify safety', () => {
    it('handles non-serializable tool responses gracefully', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      // Create a circular reference
      const circular: Record<string, unknown> = { key: 'value' };
      circular.self = circular;

      const handler: ToolHandler = async () => ({
        toolResponse: { status: 'success', message: 'ok', data: circular },
      });

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: handler },
        messages: [{ role: 'user', content: 'go' }],
      });

      // Should not crash
      assert.equal(result.responseMessage.content, 'Done');
      assert.equal(result.iterations, 1);
    });
  });

  describe('hooks', () => {
    it('beforeToolCall can modify arguments', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: { text: 'original' } }]),
        textResponse('Done'),
      ]);

      let receivedArgs: Record<string, unknown> = {};
      const handler: ToolHandler = async (args) => {
        receivedArgs = args;
        return { toolResponse: { status: 'success', message: 'ok' } };
      };

      const hooks: ToolLoopHooks = {
        beforeToolCall: async (_name, args) => ({ ...args, text: 'modified' }),
      };

      await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: handler },
        messages: [{ role: 'user', content: 'go' }],
        hooks,
      });

      assert.equal(receivedArgs.text, 'modified');
    });

    it('beforeToolCall returning false blocks the tool call', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      let handlerCalled = false;
      const handler: ToolHandler = async () => {
        handlerCalled = true;
        return { toolResponse: { status: 'success', message: 'ok' } };
      };

      const hooks: ToolLoopHooks = {
        beforeToolCall: async () => false as const,
      };

      await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: handler },
        messages: [{ role: 'user', content: 'go' }],
        hooks,
      });

      assert.equal(handlerCalled, false);
    });

    it('afterToolCall is invoked after tool execution', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      let afterCalled = false;
      let afterName = '';
      const hooks: ToolLoopHooks = {
        afterToolCall: async (name, _result) => {
          afterCalled = true;
          afterName = name;
        },
      };

      await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'go' }],
        hooks,
      });

      assert.equal(afterCalled, true);
      assert.equal(afterName, 'echo');
    });

    it('shouldBreakEarly terminates the loop', async () => {
      const { provider } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        // No follow-up response needed since we break early
      ]);

      const hooks: ToolLoopHooks = {
        shouldBreakEarly: () => true,
      };

      const result = await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'go' }],
        hooks,
      });

      assert.equal(result.iterations, 1);
    });

    it('decideFollowupToolChoice overrides default behavior', async () => {
      const { provider, requests } = createMockProvider([
        toolCallResponse([{ id: 'c1', name: 'echo', args: {} }]),
        textResponse('Done'),
      ]);

      const hooks: ToolLoopHooks = {
        decideFollowupToolChoice: () => 'none',
      };

      await executeToolLoop({
        provider, model: 'test', tools: [echoTool], toolHandlers: { echo: echoHandler },
        messages: [{ role: 'user', content: 'go' }],
        hooks,
      });

      // The follow-up request should have no tools
      assert.equal(requests[1].tools, undefined);
    });

    it('onProviderError recovers from provider failures', async () => {
      const provider: LlmProvider = {
        async createCompletion() { throw new Error('API down'); },
      };

      const hooks: ToolLoopHooks = {
        onProviderError: async () => ({ role: 'assistant', content: 'Recovered response' }),
      };

      const result = await executeToolLoop({
        provider, model: 'test', tools: [], toolHandlers: {},
        messages: [{ role: 'user', content: 'go' }],
        hooks,
      });

      assert.equal(result.responseMessage.content, 'Recovered response');
    });

    it('onProviderError returning null causes error to propagate', async () => {
      const provider: LlmProvider = {
        async createCompletion() { throw new Error('API down'); },
      };

      const hooks: ToolLoopHooks = {
        onProviderError: async () => null,
      };

      await assert.rejects(
        () => executeToolLoop({
          provider, model: 'test', tools: [], toolHandlers: {},
          messages: [{ role: 'user', content: 'go' }],
          hooks,
        }),
        /API down/
      );
    });
  });

  describe('abort signal', () => {
    it('throws before initial call when signal already aborted', async () => {
      const { provider } = createMockProvider([textResponse('Hi')]);
      const controller = new AbortController();
      controller.abort(new Error('cancelled'));

      await assert.rejects(
        () => executeToolLoop({
          provider, model: 'test', tools: [], toolHandlers: {},
          messages: [{ role: 'user', content: 'go' }],
          signal: controller.signal,
        }),
        /cancelled/
      );
    });

    it('uses signal.reason when available', async () => {
      const { provider } = createMockProvider([textResponse('Hi')]);
      const controller = new AbortController();
      const customReason = new Error('custom abort reason');
      controller.abort(customReason);

      try {
        await executeToolLoop({
          provider, model: 'test', tools: [], toolHandlers: {},
          messages: [{ role: 'user', content: 'go' }],
          signal: controller.signal,
        });
        assert.fail('Should have thrown');
      } catch (err) {
        assert.equal(err, customReason);
      }
    });

    it('throws default error when signal has no reason', async () => {
      const { provider } = createMockProvider([textResponse('Hi')]);
      const controller = new AbortController();
      controller.abort();

      try {
        await executeToolLoop({
          provider, model: 'test', tools: [], toolHandlers: {},
          messages: [{ role: 'user', content: 'go' }],
          signal: controller.signal,
        });
        assert.fail('Should have thrown');
      } catch (err) {
        // signal.reason is set by abort() — in Node it defaults to an AbortError
        assert.ok(err);
      }
    });

    it('passes signal through to provider requests', async () => {
      const controller = new AbortController();
      const { provider, requests } = createMockProvider([textResponse('Hi')]);

      await executeToolLoop({
        provider, model: 'test', tools: [], toolHandlers: {},
        messages: [{ role: 'user', content: 'go' }],
        signal: controller.signal,
      });

      assert.equal(requests[0].signal, controller.signal);
    });
  });

  describe('provider error handling', () => {
    it('throws when provider returns no choices', async () => {
      const provider: LlmProvider = {
        async createCompletion() {
          return { choices: [] } as LlmCompletionResponse;
        },
      };

      await assert.rejects(
        () => executeToolLoop({
          provider, model: 'test', tools: [], toolHandlers: {},
          messages: [{ role: 'user', content: 'go' }],
        }),
        /No response from LLM provider/
      );
    });
  });
});
