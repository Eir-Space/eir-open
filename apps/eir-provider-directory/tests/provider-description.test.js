import { describe, expect, it } from 'vitest'
import {
  extractDescription,
  extractProviderInsights,
  getProviderDescription,
  stripHtml
} from '../lib/provider-description'

describe('provider description utils', () => {
  it('strips html and entities', () => {
    const text = stripHtml('<p>Hello&nbsp;<strong>World</strong> &amp; team</p>')
    expect(text).toBe('Hello World & team')
  })

  it('extracts text from unit section content', () => {
    const html = '<div class="unit__section__content"><p>Hälsocentralen erbjuder bred vård och lång erfarenhet för alla åldrar.</p></div>'
    const description = extractDescription(html)
    expect(description).toContain('Hälsocentralen erbjuder bred vård')
  })

  it('extracts self-referral and e-services from preloaded state', () => {
    const html =
      '<script>window.__PRELOADED_STATE__ = {"__PRELOADED_STATE__":{"Content":{"Card":{"DisplayName":"X","Description":["A"],"Address":"Storgatan 1","EServices":[{"ExternalId":"EGREM_X","Text":"Egen vårdbegäran","Url":"https://example.org/form","Heading":"Villkor","Description":"<ul><li>Test</li></ul>"},{"Text":"Kontakta oss","Url":"https://example.org/contact"}]}}}}.__PRELOADED_STATE__</script>'
    const insights = extractProviderInsights(html)
    expect(insights.supportsSelfReferral).toBe(true)
    expect(insights.eServices).toHaveLength(2)
    expect(insights.eServices[0].text).toBe('Egen vårdbegäran')
    expect(insights.actions[0].external_id).toBe('EGREM_X')
    expect(insights.actions[0].action_code).toBe('EGREM')
    expect(insights.actions[0].description_text).toContain('Test')
    expect(insights.profile.display_name).toBe('X')
  })

  it('gets provider description from local fields', () => {
    const provider = { metadata: { summary: 'Lokalt sammanfattad vårdbeskrivning.' } }
    expect(getProviderDescription(provider)).toBe('Lokalt sammanfattad vårdbeskrivning.')
  })
})
