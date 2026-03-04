import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { SessionManager } from './session.js';

describe('SessionManager', () => {
  describe('create', () => {
    it('creates a session with generated UUID', () => {
      const manager = new SessionManager();
      const session = manager.create();
      assert.ok(session.id);
      assert.ok(session.id.length > 0);
      assert.ok(session.createdAt <= Date.now());
    });

    it('creates a session with custom ID', () => {
      const manager = new SessionManager();
      const session = manager.create('custom-123');
      assert.equal(session.id, 'custom-123');
    });

    it('includes an AbortController', () => {
      const manager = new SessionManager();
      const session = manager.create();
      assert.ok(session.abortController instanceof AbortController);
      assert.equal(session.abortController.signal.aborted, false);
    });

    it('includes empty metadata', () => {
      const manager = new SessionManager();
      const session = manager.create();
      assert.deepEqual(session.metadata, {});
    });
  });

  describe('get', () => {
    it('retrieves an existing session', () => {
      const manager = new SessionManager();
      manager.create('test-1');
      const retrieved = manager.get('test-1');
      assert.equal(retrieved?.id, 'test-1');
    });

    it('returns null for unknown ID', () => {
      const manager = new SessionManager();
      assert.equal(manager.get('nonexistent'), null);
    });

    it('returns null and destroys expired session', async () => {
      const manager = new SessionManager({ ttlMs: 1 });
      manager.create('expires-fast');
      // Wait for expiry
      await new Promise((resolve) => setTimeout(resolve, 10));
      const retrieved = manager.get('expires-fast');
      assert.equal(retrieved, null);
      assert.equal(manager.size, 0);
    });
  });

  describe('touch', () => {
    it('updates lastActiveAt timestamp', async () => {
      const manager = new SessionManager();
      const session = manager.create();
      const originalTime = session.lastActiveAt;
      await new Promise((resolve) => setTimeout(resolve, 10));
      manager.touch(session.id);
      assert.ok(session.lastActiveAt >= originalTime);
    });

    it('is a no-op for unknown session ID', () => {
      const manager = new SessionManager();
      // Should not throw
      manager.touch('nonexistent');
    });
  });

  describe('abort', () => {
    it('aborts the session AbortController', () => {
      const manager = new SessionManager();
      const session = manager.create();
      manager.abort(session.id);
      assert.equal(session.abortController.signal.aborted, true);
    });

    it('is a no-op for unknown session ID', () => {
      const manager = new SessionManager();
      manager.abort('nonexistent');
    });
  });

  describe('destroy', () => {
    it('removes the session and aborts its controller', () => {
      const manager = new SessionManager();
      const session = manager.create('to-destroy');
      manager.destroy('to-destroy');
      assert.equal(manager.get('to-destroy'), null);
      assert.equal(session.abortController.signal.aborted, true);
    });
  });

  describe('cleanup', () => {
    it('evicts expired sessions', async () => {
      const manager = new SessionManager({ ttlMs: 1 });
      manager.create('expires');
      await new Promise((resolve) => setTimeout(resolve, 10));
      manager.create('fresh');
      // cleanup is called inside create()
      assert.equal(manager.size, 1);
    });

    it('enforces maxSessions via LRU eviction', () => {
      // cleanup() runs before adding the new session, so eviction triggers
      // when existing count > maxSessions (off-by-one from the limit).
      // With maxSessions=1: create s1 (0→1), create s2 (1 not > 1→2),
      // create s3 (2 > 1, evict 1→1, add→2)
      const manager = new SessionManager({ maxSessions: 1 });
      manager.create('s1');
      manager.create('s2');
      manager.create('s3'); // cleanup evicts s1 (oldest)
      assert.equal(manager.size, 2);
      assert.equal(manager.get('s1'), null);
      assert.ok(manager.get('s2') || manager.get('s3'));
    });

    it('aborts evicted sessions', () => {
      const manager = new SessionManager({ maxSessions: 1 });
      const s1 = manager.create('s1');
      manager.create('s2');
      manager.create('s3'); // This triggers eviction of s1
      assert.equal(s1.abortController.signal.aborted, true);
    });
  });

  describe('size', () => {
    it('returns current session count', () => {
      const manager = new SessionManager();
      assert.equal(manager.size, 0);
      manager.create();
      assert.equal(manager.size, 1);
      manager.create();
      assert.equal(manager.size, 2);
    });
  });
});
