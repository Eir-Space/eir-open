const SELF_REFERRAL_PATTERN = /egen vårdbegäran|egen vardbegaran|egen remiss/i

export function stripHtml(input) {
  if (typeof input !== 'string') return ''

  return input
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim()
}

export function extractPreloadedState(html) {
  if (typeof html !== 'string') return null

  const preloadedMatch = html.match(
    /window\.__PRELOADED_STATE__\s*=\s*(\{[\s\S]*?\})\.__PRELOADED_STATE__/
  )
  if (!preloadedMatch || !preloadedMatch[1]) return null

  try {
    const parsed = JSON.parse(preloadedMatch[1])
    return parsed?.__PRELOADED_STATE__ || null
  } catch {
    return null
  }
}

export function extractProviderSnapshot(html) {
  const preloaded = extractPreloadedState(html)
  const card = preloaded?.Content?.Card
  const fallbackActions = extractEServicesFromHtml(html)

  if (!card) {
    const supportsSelfReferral = fallbackActions.some(action => SELF_REFERRAL_PATTERN.test(action.text))
    return {
      description: '',
      supportsSelfReferral,
      actions: fallbackActions.map(action => ({
        external_id: '',
        action_code: '',
        text: action.text,
        url: action.url,
        heading: '',
        description_html: '',
        description_text: ''
      })),
      profile: null
    }
  }

  const actions = Array.isArray(card.EServices)
    ? card.EServices
        .map(service => ({
          external_id: service?.ExternalId || '',
          action_code: extractActionCode(service?.ExternalId),
          text: service?.Text || '',
          url: service?.Url || '',
          heading: service?.Heading || '',
          description_html: service?.Description || '',
          description_text: stripHtml(service?.Description || '')
        }))
        .filter(action => action.text || action.url)
    : fallbackActions
        .map(action => ({
          external_id: '',
          action_code: '',
          text: action.text,
          url: action.url,
          heading: '',
          description_html: '',
          description_text: ''
        }))

  const description = Array.isArray(card.Description)
    ? card.Description.join(' ').trim()
    : ''

  const supportsSelfReferral = actions.some(action => SELF_REFERRAL_PATTERN.test(action.text))

  return {
    description,
    supportsSelfReferral,
    actions,
    profile: {
      display_name: card.DisplayName || '',
      hsa_id: card.HsaId || '',
      address: card.Address || '',
      postal_address: card.PostalAddress || '',
      county: card.County || '',
      municipality: card.Municipality || '',
      website_url: card.WebsiteUrl || '',
      location: normalizeLocation(card.Location),
      road_description: normalizeStringArray(card.RoadDescription),
      description_blocks: normalizeStringArray(card.Description),
      patient_information: normalizeStringArray(card.PatientInformation),
      visitor_information: normalizeStringArray(card.VisitorInformation),
      phone: normalizePhone(card.Phone),
      about_us: normalizeAboutUs(card.AboutUs),
      related_units: normalizeRelatedUnits(card.Related)
    }
  }
}

export function extractDescription(html) {
  const snapshot = extractProviderSnapshot(html)
  if (snapshot.description) return snapshot.description

  const selectors = [
    /<div[^>]*class="[^"]*unit__section__content[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
    /<section[^>]*class="[^"]*unit__section[^"]*"[^>]*>([\s\S]*?)<\/section>/i,
    /<meta[^>]*name="description"[^>]*content="([^"]+)"/i,
    /<meta[^>]*property="og:description"[^>]*content="([^"]+)"/i
  ]

  for (const pattern of selectors) {
    const match = html.match(pattern)
    if (!match || !match[1]) continue
    const text = stripHtml(match[1])
    if (text.length > 40) return text
  }
  return ''
}

export function extractProviderInsights(html) {
  const snapshot = extractProviderSnapshot(html)

  return {
    description: snapshot.description,
    supportsSelfReferral: snapshot.supportsSelfReferral,
    eServices: snapshot.actions.map(action => ({
      text: action.text,
      url: action.url
    })),
    actions: snapshot.actions,
    profile: snapshot.profile
  }
}

function extractEServicesFromHtml(html) {
  const serviceRegex =
    /<a[^>]*class="[^"]*e-tjänster[^"]*"[^>]*(?:href="([^"]*)")?[^>]*>\s*<span>([^<]+)<\/span>\s*<\/a>/gi
  const services = []
  let match

  while ((match = serviceRegex.exec(html)) !== null) {
    const url = stripHtml(match[1] || '')
    const text = stripHtml(match[2] || '')
    if (text) services.push({ text, url })
  }

  return services
}

function extractActionCode(externalId) {
  const raw = typeof externalId === 'string' ? externalId : ''
  const firstSegment = raw.split('_')[0] || ''
  const code = firstSegment.includes('-') ? firstSegment.split('-')[0] : firstSegment
  return code || ''
}

function normalizeLocation(location) {
  if (!location || typeof location !== 'object') return null
  const latitude = Number(location.latitude)
  const longitude = Number(location.longitude)
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null
  return { latitude, longitude }
}

function normalizeStringArray(input) {
  if (Array.isArray(input)) {
    return input.map(item => String(item || '').trim()).filter(Boolean)
  }

  if (input && typeof input === 'object') {
    return Object.values(input)
      .map(item => String(item || '').trim())
      .filter(Boolean)
  }

  if (typeof input === 'string' && input.trim()) {
    return [input.trim()]
  }

  return []
}

function normalizePhone(phoneInput) {
  if (!Array.isArray(phoneInput)) return []

  return phoneInput.map(entry => ({
    title: entry?.Title || '',
    numbers: Array.isArray(entry?.Numbers)
      ? entry.Numbers.map(number => ({
          national: number?.National || '',
          international: number?.International || ''
        }))
      : [],
    schedule: Array.isArray(entry?.Schedule)
      ? entry.Schedule.map(day => ({
          day: day?.Day || '',
          spans: Array.isArray(day?.Spans)
            ? day.Spans.map(span => ({
                period: span?.Period || ''
              }))
            : []
        }))
      : []
  }))
}

function normalizeAboutUs(aboutUs) {
  if (!aboutUs || typeof aboutUs !== 'object') return null

  return {
    description: normalizeStringArray(aboutUs.Description),
    owner_type: aboutUs.OwnerAndFinancing?.OwnerType || '',
    financing_text: aboutUs.OwnerAndFinancing?.FinancingText || '',
    price_links: Array.isArray(aboutUs.OwnerAndFinancing?.PriceLinks)
      ? aboutUs.OwnerAndFinancing.PriceLinks.map(link => ({
          text: link?.Text || '',
          url: link?.Url || ''
        }))
      : []
  }
}

function normalizeRelatedUnits(related) {
  if (!related || typeof related !== 'object') {
    return {
      related_units: [],
      more_units_like: []
    }
  }

  return {
    related_units: Array.isArray(related.RelatedUnits)
      ? related.RelatedUnits.map(item => ({
          text: item?.Text || '',
          url: item?.Url || ''
        }))
      : [],
    more_units_like: Array.isArray(related.MoreUnitsLike)
      ? related.MoreUnitsLike.map(item => ({
          text: item?.Text || '',
          url: item?.Url || ''
        }))
      : []
  }
}

export function getProviderDescription(provider) {
  const candidates = [
    provider?.description,
    provider?.summary,
    provider?.about,
    provider?.unit_description,
    provider?.metadata?.description,
    provider?.metadata?.summary,
    provider?.profile_1177?.description
  ]

  return candidates.find(value => typeof value === 'string' && value.trim().length > 0) || ''
}
