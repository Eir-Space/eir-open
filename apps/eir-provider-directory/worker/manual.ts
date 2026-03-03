import { handleApiRoute, renderPage } from "../dist/server/entry.js";

interface Env {
  ASSETS: Fetcher;
  PROVIDER_DATA_BUCKET?: R2Bucket;
  PROVIDER_DB?: D1Database;
}

type RuntimeGlobals = typeof globalThis & {
  __EIR_ASSET_FETCH__?: (assetPath: string) => Promise<Response>;
  __EIR_R2_GET_JSON__?: (key: string) => Promise<unknown>;
  __EIR_D1_QUERY__?: (sql: string, params?: unknown[]) => Promise<unknown[]>;
  __EIR_VINEXT_MANIFEST_INIT__?: Promise<void>;
  __VINEXT_SSR_MANIFEST__?: Record<string, string[]>;
  __VINEXT_CLIENT_ENTRY__?: string;
};

function globals(): RuntimeGlobals {
  return globalThis as RuntimeGlobals;
}

async function ensureVinextManifests(env: Env, request: Request, origin: string) {
  const g = globals();
  if (g.__EIR_VINEXT_MANIFEST_INIT__) {
    await g.__EIR_VINEXT_MANIFEST_INIT__;
    return;
  }

  g.__EIR_VINEXT_MANIFEST_INIT__ = (async () => {
    const fetchAssetJson = async <T>(assetPath: string): Promise<T | null> => {
      const assetUrl = new URL(assetPath, origin);
      const response = await env.ASSETS.fetch(new Request(assetUrl.toString(), request));
      if (!response.ok) return null;
      return response.json() as Promise<T>;
    };

    const ssrManifest = await fetchAssetJson<Record<string, string[]>>('/.vite/ssr-manifest.json');
    if (ssrManifest) {
      g.__VINEXT_SSR_MANIFEST__ = ssrManifest;
    }

    const viteManifest = await fetchAssetJson<Record<string, { file?: string; isEntry?: boolean }>>('/.vite/manifest.json');
    if (!viteManifest) return;

    for (const key of Object.keys(viteManifest)) {
      const entry = viteManifest[key];
      if (entry?.isEntry && entry.file) {
        g.__VINEXT_CLIENT_ENTRY__ = entry.file;
        break;
      }
    }
  })();

  await g.__EIR_VINEXT_MANIFEST_INIT__;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const g = globals();
    const url = new URL(request.url);
    const resolvedUrl = `${url.pathname}${url.search}`;

    g.__EIR_ASSET_FETCH__ = (assetPath: string) => {
      const assetUrl = new URL(assetPath, url.origin);
      return env.ASSETS.fetch(new Request(assetUrl.toString(), request));
    };

    if (env.PROVIDER_DATA_BUCKET) {
      g.__EIR_R2_GET_JSON__ = async (key: string) => {
        const object = await env.PROVIDER_DATA_BUCKET!.get(key);
        if (!object) return null;
        return object.json();
      };
    } else {
      g.__EIR_R2_GET_JSON__ = undefined;
    }

    if (env.PROVIDER_DB) {
      g.__EIR_D1_QUERY__ = async (sql: string, params: unknown[] = []) => {
        const statement = env.PROVIDER_DB!.prepare(sql).bind(...params);
        const result = await statement.all();
        return Array.isArray(result.results) ? result.results : [];
      };
    } else {
      g.__EIR_D1_QUERY__ = undefined;
    }

    if (url.pathname.startsWith('/api/') || url.pathname === '/api') {
      return handleApiRoute(request, resolvedUrl);
    }

    await ensureVinextManifests(env, request, url.origin);

    const page = await renderPage(request, resolvedUrl, g.__VINEXT_SSR_MANIFEST__ || null);
    if (page) {
      return page;
    }

    return env.ASSETS.fetch(request);
  },
};
