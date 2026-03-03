import { extractDescription, extractProviderInsights } from '../../lib/provider-description'

const CACHE_TTL_MS = 1000 * 60 * 60 * 6
const emptyPayload = {
  description: '',
  supportsSelfReferral: false,
  eServices: [],
  actions: [],
  profile: null
}

const cache = globalThis.__eirProviderDescriptionCache || new Map()
if (!globalThis.__eirProviderDescriptionCache) {
  globalThis.__eirProviderDescriptionCache = cache
}

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  const url = req.query.url
  if (!url || typeof url !== 'string') {
    return res.status(400).json({ error: 'Missing url' })
  }

  try {
    const parsed = new URL(url)
    if (!parsed.hostname.includes('1177.se')) {
      return res.status(400).json({ error: 'Only 1177.se urls are allowed' })
    }

    const allowLive = req.query.allow_live === 'true'
    if (!allowLive) {
      return res.status(200).json({
        ...emptyPayload,
        liveFetchDisabled: true
      })
    }

    const cached = readCache(parsed.toString())
    if (cached) {
      return res.status(200).json({
        ...cached,
        fromCache: true
      })
    }

    const response = await fetch(parsed.toString(), {
      headers: {
        'user-agent': 'EIR Provider Directory/1.0'
      }
    })

    if (response.status === 429 || response.status === 403) {
      return res.status(200).json({
        ...emptyPayload,
        rateLimited: true
      })
    }

    if (!response.ok) {
      return res.status(200).json(emptyPayload)
    }

    const html = await response.text()
    const description = extractDescription(html)
    const insights = extractProviderInsights(html)
    const payload = {
      description,
      supportsSelfReferral: insights.supportsSelfReferral,
      eServices: insights.eServices,
      actions: insights.actions || [],
      profile: insights.profile || null
    }
    writeCache(parsed.toString(), payload)
    return res.status(200).json(payload)
  } catch {
    return res.status(200).json(emptyPayload)
  }
}

function readCache(url) {
  const entry = cache.get(url)
  if (!entry) return null
  if (Date.now() - entry.timestamp > CACHE_TTL_MS) {
    cache.delete(url)
    return null
  }
  return entry.payload
}

function writeCache(url, payload) {
  cache.set(url, {
    timestamp: Date.now(),
    payload
  })
}
