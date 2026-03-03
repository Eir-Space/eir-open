import { randomUUID } from 'node:crypto';

export interface Session {
  id: string;
  createdAt: number;
  lastActiveAt: number;
  abortController: AbortController;
  metadata: Record<string, unknown>;
}

export interface SessionManagerOptions {
  /** Session time-to-live in milliseconds. Default: 30 minutes. */
  ttlMs?: number;
  /** Maximum number of concurrent sessions. Default: 100. Evicts least-recently-active. */
  maxSessions?: number;
}

/**
 * Lightweight session manager with TTL expiry and LRU eviction.
 * Each session carries an AbortController whose signal can be passed to the tool loop.
 */
export class SessionManager {
  private sessions = new Map<string, Session>();
  private readonly ttlMs: number;
  private readonly maxSessions: number;

  constructor(options?: SessionManagerOptions) {
    this.ttlMs = options?.ttlMs ?? 30 * 60 * 1000;
    this.maxSessions = options?.maxSessions ?? 100;
  }

  /** Create a new session. Runs cleanup first to evict expired/over-limit sessions. */
  create(id?: string): Session {
    this.cleanup();

    const session: Session = {
      id: id ?? randomUUID(),
      createdAt: Date.now(),
      lastActiveAt: Date.now(),
      abortController: new AbortController(),
      metadata: {},
    };

    this.sessions.set(session.id, session);
    return session;
  }

  /** Get a session by ID. Returns null if not found or expired. */
  get(id: string): Session | null {
    const session = this.sessions.get(id);
    if (!session) return null;

    if (Date.now() - session.lastActiveAt > this.ttlMs) {
      this.destroy(id);
      return null;
    }

    return session;
  }

  /** Update the session's last-active timestamp. */
  touch(id: string): void {
    const session = this.sessions.get(id);
    if (session) {
      session.lastActiveAt = Date.now();
    }
  }

  /** Abort a session's in-flight operations via its AbortController. */
  abort(id: string): void {
    const session = this.sessions.get(id);
    if (session) {
      session.abortController.abort();
    }
  }

  /** Remove a session, aborting any in-flight operations. */
  destroy(id: string): void {
    const session = this.sessions.get(id);
    if (session) {
      session.abortController.abort();
      this.sessions.delete(id);
    }
  }

  /** Evict expired sessions and enforce maxSessions via LRU eviction. */
  cleanup(): void {
    const now = Date.now();

    // Evict expired
    for (const [id, session] of this.sessions) {
      if (now - session.lastActiveAt > this.ttlMs) {
        session.abortController.abort();
        this.sessions.delete(id);
      }
    }

    // LRU eviction if over limit
    if (this.sessions.size > this.maxSessions) {
      const sorted = Array.from(this.sessions.entries())
        .sort(([, a], [, b]) => a.lastActiveAt - b.lastActiveAt);

      const toEvict = sorted.slice(0, this.sessions.size - this.maxSessions);
      for (const [id, session] of toEvict) {
        session.abortController.abort();
        this.sessions.delete(id);
      }
    }
  }

  /** Get the number of active sessions. */
  get size(): number {
    return this.sessions.size;
  }
}
