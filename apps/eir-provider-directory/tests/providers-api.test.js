import fs from 'fs'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import handler from '../pages/api/providers'

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

describe('GET /api/providers', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
  })

  it('prefers verified dataset and filters self-referral using verified flag', async () => {
    const verifiedData = {
      providers: [
        {
          id: 'a',
          name: 'Alpha',
          type: 'specialist',
          specialty: [],
          services: { self_referral: true, self_referral_verified: false },
          location: { address: 'A', coordinates: { lat: 1, lng: 1 } },
          contact: {}
        },
        {
          id: 'b',
          name: 'Beta',
          type: 'specialist',
          specialty: [],
          services: { self_referral: false, self_referral_verified: true },
          location: { address: 'B', coordinates: { lat: 1, lng: 1 } },
          contact: {}
        }
      ]
    }

    vi.spyOn(fs, 'existsSync').mockReturnValue(true)
    const readSpy = vi.spyOn(fs, 'readFileSync').mockImplementation(filePath => {
      if (String(filePath).includes('providers-sweden-verified.json')) {
        return JSON.stringify(verifiedData)
      }
      return JSON.stringify({ providers: [] })
    })

    const req = { method: 'GET', query: { self_referral: 'true', limit: '100' } }
    const res = createRes()
    await handler(req, res)

    expect(res.statusCode).toBe(200)
    expect(res.body.providers).toHaveLength(1)
    expect(res.body.providers[0].id).toBe('b')
    expect(readSpy).toHaveBeenCalled()
    expect(
      readSpy.mock.calls.some(call => String(call[0]).includes('providers-sweden-verified.json'))
    ).toBe(true)
  })

  it('uses sample dataset when sample=true', async () => {
    const sampleData = {
      providers: [
        {
          id: 'sample-1',
          name: 'Sample Clinic',
          type: 'primary_care',
          specialty: [],
          services: { self_referral: false },
          location: { address: 'Sample', coordinates: { lat: 1, lng: 1 } },
          contact: {}
        }
      ]
    }

    vi.spyOn(fs, 'existsSync').mockReturnValue(true)
    const readSpy = vi.spyOn(fs, 'readFileSync').mockImplementation(filePath => {
      if (String(filePath).includes('providers-sweden-sample.json')) {
        return JSON.stringify(sampleData)
      }
      return JSON.stringify({ providers: [] })
    })

    const req = { method: 'GET', query: { sample: 'true', limit: '100' } }
    const res = createRes()
    await handler(req, res)

    expect(res.statusCode).toBe(200)
    expect(res.body.providers).toHaveLength(1)
    expect(res.body.providers[0].id).toBe('sample-1')
    expect(
      readSpy.mock.calls.some(call => String(call[0]).includes('providers-sweden-sample.json'))
    ).toBe(true)
  })
})
