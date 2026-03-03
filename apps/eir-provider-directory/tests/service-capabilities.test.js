import { describe, expect, it } from 'vitest'
import { hasMVKServices, hasVideoConsultation } from '../lib/service-capabilities'

describe('service capability helpers', () => {
  it('respects explicit boolean flags', () => {
    const provider = {
      services: {
        video_consultation: true,
        mvk_services: true
      }
    }
    expect(hasVideoConsultation(provider)).toBe(true)
    expect(hasMVKServices(provider)).toBe(true)
  })

  it('derives video capability from structured actions', () => {
    const provider = {
      services: {
        e_services_structured: [
          {
            text: 'Boka videobesök',
            description_text: ''
          }
        ]
      }
    }
    expect(hasVideoConsultation(provider)).toBe(true)
  })

  it('derives mvk capability from structured actions', () => {
    const provider = {
      services: {
        e_services_structured: [
          {
            text: 'MVK egen inloggning',
            description_text: ''
          }
        ]
      }
    }
    expect(hasMVKServices(provider)).toBe(true)
  })
})
