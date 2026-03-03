import fs from 'fs'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import handler from '../pages/api/search'

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

describe('GET /api/search', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
  })

  it('uses verified dataset and marks care focus matches', async () => {
    const verifiedData = {
      providers: [
        {
          id: 'mh-1',
          name: 'Specialist Center',
          type: 'mental_health',
          specialty: ['psykiatri'],
          services: { self_referral_verified: true },
          location: { address: 'Stockholm' },
          contact: {}
        }
      ]
    }

    vi.spyOn(fs, 'existsSync').mockReturnValue(true)
    vi.spyOn(fs, 'readFileSync').mockImplementation(filePath => {
      if (String(filePath).includes('providers-sweden-verified.json')) {
        return JSON.stringify(verifiedData)
      }
      return JSON.stringify({ providers: [] })
    })

    const req = { method: 'GET', query: { q: 'psykiatri', limit: '10' } }
    const res = createRes()
    await handler(req, res)

    expect(res.statusCode).toBe(200)
    expect(res.body.results).toHaveLength(1)
    expect(res.body.results[0].id).toBe('mh-1')
    expect(res.body.results[0].matchedFields).toContain('care_focus')
  })

  it('returns suggestions when there are no direct matches', async () => {
    const dataset = {
      providers: [
        {
          id: 'd-1',
          name: 'Dental Clinic',
          type: 'dental',
          specialty: ['tandvård'],
          services: {},
          location: { address: 'Uppsala' },
          contact: {}
        }
      ]
    }

    vi.spyOn(fs, 'existsSync').mockReturnValue(true)
    vi.spyOn(fs, 'readFileSync').mockReturnValue(JSON.stringify(dataset))

    const req = { method: 'GET', query: { q: 'psy', limit: '10' } }
    const res = createRes()
    await handler(req, res)

    expect(res.statusCode).toBe(200)
    expect(Array.isArray(res.body.suggestions)).toBe(true)
    expect(res.body.suggestions.length).toBeGreaterThan(0)
  })
})
