import { describe, expect, it } from 'vitest'
import { distanceFromUser, haversineKm } from '../lib/distance'

describe('distance utils', () => {
  it('calculates zero distance for same coordinates', () => {
    expect(haversineKm(59.3293, 18.0686, 59.3293, 18.0686)).toBeCloseTo(0, 5)
  })

  it('calculates reasonable distance between Stockholm and Gothenburg', () => {
    const km = haversineKm(59.3293, 18.0686, 57.7089, 11.9746)
    expect(km).toBeGreaterThan(390)
    expect(km).toBeLessThan(410)
  })

  it('returns Infinity when provider has no coordinates', () => {
    const km = distanceFromUser({ location: { coordinates: {} } }, { lat: 59, lng: 18 })
    expect(km).toBe(Number.POSITIVE_INFINITY)
  })
})
