import { beforeEach, describe, expect, it, vi } from 'vitest'
import handler from '../pages/api/provider-description'

function createRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code
      return this
    },
    json(payload) {
      this.body = payload
      return this
    }
  }
}

describe('GET /api/provider-description', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
  })

  it('rejects non-1177 urls', async () => {
    const req = { method: 'GET', query: { url: 'https://example.com' } }
    const res = createRes()
    await handler(req, res)
    expect(res.statusCode).toBe(400)
  })

  it('extracts description from 1177 html', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        text: async () =>
          '<div class="unit__section__content"><p>Lång beskrivning av vård och kompetens för patienter i regionen.</p></div><a class="card-link-list__link e-tjänster"><span>Egen vårdbegäran</span></a>'
      })
    )

    const req = {
      method: 'GET',
      query: { allow_live: 'true', url: 'https://www.1177.se/hitta-vard/kontaktkort/live-a/' }
    }
    const res = createRes()
    await handler(req, res)
    expect(res.statusCode).toBe(200)
    expect(res.body.description).toContain('Lång beskrivning av vård')
    expect(res.body.supportsSelfReferral).toBe(true)
    expect(Array.isArray(res.body.eServices)).toBe(true)
  })

  it('returns empty description on fetch errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network down')))
    const req = {
      method: 'GET',
      query: { allow_live: 'true', url: 'https://www.1177.se/hitta-vard/kontaktkort/live-b/' }
    }
    const res = createRes()
    await handler(req, res)
    expect(res.statusCode).toBe(200)
    expect(res.body).toEqual({
      description: '',
      supportsSelfReferral: false,
      eServices: [],
      actions: [],
      profile: null
    })
  })

  it('does not fetch when allow_live is not set', async () => {
    const fetchSpy = vi.fn()
    vi.stubGlobal('fetch', fetchSpy)
    const req = { method: 'GET', query: { url: 'https://www.1177.se/hitta-vard/kontaktkort/live-c/' } }
    const res = createRes()
    await handler(req, res)
    expect(res.statusCode).toBe(200)
    expect(fetchSpy).not.toHaveBeenCalled()
    expect(res.body.liveFetchDisabled).toBe(true)
  })

  it('returns rate-limited flag on 429', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 429
      })
    )
    const req = {
      method: 'GET',
      query: { allow_live: 'true', url: 'https://www.1177.se/hitta-vard/kontaktkort/live-d/' }
    }
    const res = createRes()
    await handler(req, res)
    expect(res.statusCode).toBe(200)
    expect(res.body.rateLimited).toBe(true)
  })
})
