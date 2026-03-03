import { describe, expect, it } from 'vitest'
import { filterProviders } from '../lib/provider-filters'

const providers = [
  {
    id: 'a',
    name: 'Alpha Care',
    type: 'primary_care',
    specialty: ['allmänmedicin'],
    services: {
      self_referral: false,
      video_consultation: false,
      mvk_services: false,
      e_services_structured: [{ text: 'Boka videobesök', description_text: '' }]
    },
    location: { address: 'Stockholm', coordinates: { lat: 59.3, lng: 18.0 } }
  },
  {
    id: 'b',
    name: 'Beta Specialist',
    type: 'specialist',
    specialty: ['dermatologi'],
    services: {
      self_referral: true,
      self_referral_verified: false,
      video_consultation: false,
      mvk_services: true
    },
    location: { address: 'Uppsala', coordinates: { lat: 59.85, lng: 17.63 } }
  }
]

describe('filterProviders', () => {
  it('filters by type and service flags', () => {
    const result = filterProviders(providers, {
      selectedType: 'specialist',
      searchQuery: '',
      serviceFilters: { selfReferral: true, videoConsultation: false, mvkServices: false },
      careFocusFilters: [],
      userLocation: null,
      nearbyOnly: false,
      nearbyRadiusKm: 25
    })
    expect(result).toHaveLength(0)
  })

  it('filters by nearby radius when enabled', () => {
    const result = filterProviders(providers, {
      selectedType: 'all',
      searchQuery: '',
      serviceFilters: { selfReferral: false, videoConsultation: false, mvkServices: false },
      careFocusFilters: [],
      userLocation: { lat: 59.3, lng: 18.0 },
      nearbyOnly: true,
      nearbyRadiusKm: 10
    })
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe('a')
  })

  it('filters video consultation using derived action capability', () => {
    const result = filterProviders(providers, {
      selectedType: 'all',
      searchQuery: '',
      serviceFilters: { selfReferral: false, videoConsultation: true, mvkServices: false },
      careFocusFilters: [],
      userLocation: null,
      nearbyOnly: false,
      nearbyRadiusKm: 50
    })
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe('a')
  })

  it('matches any selected service filter (OR behavior)', () => {
    const result = filterProviders(providers, {
      selectedType: 'all',
      searchQuery: '',
      serviceFilters: { selfReferral: false, videoConsultation: true, mvkServices: true },
      careFocusFilters: [],
      userLocation: null,
      nearbyOnly: false,
      nearbyRadiusKm: 50
    })
    expect(result).toHaveLength(2)
  })

  it('filters by care focus categories', () => {
    const result = filterProviders(providers, {
      selectedType: 'all',
      searchQuery: '',
      serviceFilters: { selfReferral: false, videoConsultation: false, mvkServices: false },
      careFocusFilters: ['skin'],
      userLocation: null,
      nearbyOnly: false,
      nearbyRadiusKm: 50
    })
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe('b')
  })
})
