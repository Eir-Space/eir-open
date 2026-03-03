import { describe, expect, it } from 'vitest'
import {
  deriveProviderCareFocuses,
  findCareFocusesInText,
  providerHasCareFocus
} from '../lib/care-focus'

describe('care focus utilities', () => {
  it('derives care focuses from type and specialty', () => {
    const provider = {
      type: 'specialist',
      name: 'Hudspecialisten',
      specialty: ['dermatologi']
    }
    const focuses = deriveProviderCareFocuses(provider)
    expect(focuses).toContain('skin')
  })

  it('falls back to general when no focus match exists', () => {
    const provider = {
      type: 'other',
      name: 'Generic Clinic',
      specialty: []
    }
    const focuses = deriveProviderCareFocuses(provider)
    expect(focuses).toEqual(['general'])
  })

  it('matches providers against selected focus', () => {
    const provider = {
      type: 'mental_health',
      name: 'Psykiatri mottagning',
      specialty: ['psykiatri']
    }
    expect(providerHasCareFocus(provider, ['mental-health'])).toBe(true)
    expect(providerHasCareFocus(provider, ['skin'])).toBe(false)
  })

  it('finds care focus intent in query text', () => {
    const focuses = findCareFocusesInText('jag söker psykiatri nära mig')
    expect(focuses).toContain('mental-health')
  })
})
