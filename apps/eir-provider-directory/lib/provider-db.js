import { hasVerifiedSelfReferral } from './self-referral'
import { findCareFocusesInText, providerHasCareFocus } from './care-focus'

function getRuntimeD1Query() {
  const g = globalThis
  if (typeof g.__EIR_D1_QUERY__ === 'function') {
    return g.__EIR_D1_QUERY__
  }
  return null
}

export function hasProviderDatabase() {
  return Boolean(getRuntimeD1Query())
}

async function d1All(sql, params = []) {
  const queryFn = getRuntimeD1Query()
  if (!queryFn) {
    throw new Error('D1 runtime is not available')
  }

  const rows = await queryFn(sql, params)
  return Array.isArray(rows) ? rows : []
}

function toNumber(value, fallback = 0) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
}

function parseJsonSafe(value, fallback) {
  if (!value) return fallback
  try {
    return JSON.parse(value)
  } catch {
    return fallback
  }
}

function rowToProvider(row, includeDescription = false) {
  const specialty = parseJsonSafe(row.specialty_json, [])
  const services = parseJsonSafe(row.services_json, {})
  const metadata = parseJsonSafe(row.metadata_json, {})

  const provider = {
    id: row.id,
    name: row.name,
    type: row.type,
    specialty: Array.isArray(specialty) ? specialty : [],
    contact: {
      phone: row.phone || null,
      internationalPhone: row.international_phone || null,
      email: row.email || null,
      website: row.website || null
    },
    location: {
      address: row.address || 'Address unavailable',
      coordinates: {
        lat: row.lat === null || row.lat === undefined ? null : Number(row.lat),
        lng: row.lng === null || row.lng === undefined ? null : Number(row.lng)
      }
    },
    services,
    metadata
  }

  if (includeDescription && row.description) {
    provider.description = row.description
  }

  return provider
}

function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371
  const dLat = toRadians(lat2 - lat1)
  const dLng = toRadians(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2)

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180)
}

function buildProviderWhereClause(query) {
  const where = []
  const params = []

  if (query.type && query.type !== 'all') {
    where.push('type = ?')
    params.push(query.type)
  }

  if (query.specialty) {
    where.push('specialty_text LIKE ?')
    params.push(`%${String(query.specialty).toLowerCase()}%`)
  }

  if (query.self_referral === 'true') {
    where.push('self_referral_verified = 1')
  }

  if (query.location) {
    const term = `%${String(query.location).toLowerCase()}%`
    where.push('(LOWER(address) LIKE ? OR LOWER(name) LIKE ?)')
    params.push(term, term)
  }

  return { where, params }
}

function withDistanceFilter(providers, lat, lng, radiusKm) {
  return providers
    .map(provider => {
      const providerLat = provider.location?.coordinates?.lat
      const providerLng = provider.location?.coordinates?.lng
      if (providerLat === null || providerLng === null) return null

      const distance = calculateDistance(lat, lng, providerLat, providerLng)
      if (distance > radiusKm) return null
      return { ...provider, distance }
    })
    .filter(Boolean)
    .sort((a, b) => a.distance - b.distance)
}

export async function getProvidersFromDatabase(query = {}) {
  if (!hasProviderDatabase()) {
    return null
  }

  const limit = Math.max(1, toNumber(query.limit, 1000))
  const offset = Math.max(0, toNumber(query.offset, 0))
  const includeDescription = query.summary === 'false'
  const { where, params } = buildProviderWhereClause(query)

  const lat = query.lat !== undefined ? Number(query.lat) : null
  const lng = query.lng !== undefined ? Number(query.lng) : null
  const hasGeo = Number.isFinite(lat) && Number.isFinite(lng)
  const radiusKm = Math.max(1, toNumber(query.radius, 50))

  const columns = [
    'id',
    'name',
    'type',
    'specialty_json',
    'address',
    'lat',
    'lng',
    'phone',
    'international_phone',
    'email',
    'website',
    'services_json',
    'metadata_json',
    'description'
  ]

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''

  if (!hasGeo) {
    const countRows = await d1All(`SELECT COUNT(*) AS total FROM providers ${whereSql}`, params)
    const total = Number(countRows[0]?.total || 0)

    const rows = await d1All(
      `SELECT ${columns.join(', ')} FROM providers ${whereSql} ORDER BY name LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    )

    const providers = rows.map(row => rowToProvider(row, includeDescription))
    return { providers, total }
  }

  const dLat = radiusKm / 111
  const cosLat = Math.cos(toRadians(lat))
  const dLng = cosLat === 0 ? 180 : radiusKm / (111 * Math.abs(cosLat))

  const geoWhere = [...where, 'lat IS NOT NULL', 'lng IS NOT NULL', 'lat BETWEEN ? AND ?', 'lng BETWEEN ? AND ?']
  const geoParams = [...params, lat - dLat, lat + dLat, lng - dLng, lng + dLng]

  const geoRows = await d1All(
    `SELECT ${columns.join(', ')} FROM providers WHERE ${geoWhere.join(' AND ')}`,
    geoParams
  )

  const geoProviders = geoRows.map(row => rowToProvider(row, includeDescription))
  const filtered = withDistanceFilter(geoProviders, lat, lng, radiusKm)

  return {
    total: filtered.length,
    providers: filtered.slice(offset, offset + limit)
  }
}

export async function searchProvidersInDatabase(query, limit = 50) {
  if (!hasProviderDatabase()) {
    return null
  }

  const searchTerm = String(query || '').trim().toLowerCase()
  if (searchTerm.length < 2) {
    return { results: [], suggestions: [] }
  }

  const like = `%${searchTerm}%`
  const digits = searchTerm.replace(/\D/g, '')
  const phoneLike = `%${digits}%`

  const rows = await d1All(
    `SELECT
      id,
      name,
      type,
      specialty_json,
      address,
      lat,
      lng,
      phone,
      international_phone,
      email,
      website,
      services_json,
      metadata_json,
      description
     FROM providers
     WHERE LOWER(name) LIKE ?
       OR LOWER(address) LIKE ?
       OR specialty_text LIKE ?
       OR LOWER(type) LIKE ?
       OR id = ?
       OR REPLACE(REPLACE(COALESCE(phone, ''), '-', ''), ' ', '') LIKE ?
     LIMIT 1200`,
    [like, like, like, like, searchTerm, phoneLike]
  )

  const providers = rows.map(row => rowToProvider(row, true))
  const queryCareFocuses = findCareFocusesInText(searchTerm)

  const results = providers
    .map(provider => {
      let score = 0
      const matchedFields = []

      if (provider.name.toLowerCase().includes(searchTerm)) {
        score += 100
        if (provider.name.toLowerCase().startsWith(searchTerm)) {
          score += 50
        }
        matchedFields.push('name')
      }

      if (provider.location?.address && provider.location.address.toLowerCase().includes(searchTerm)) {
        score += 30
        matchedFields.push('address')
      }

      const specialties = Array.isArray(provider.specialty) ? provider.specialty : []
      if (specialties.some(s => s.toLowerCase().includes(searchTerm))) {
        score += 40
        matchedFields.push('specialty')
      }

      if (
        provider.type.toLowerCase().includes(searchTerm) ||
        provider.type.replace('_', ' ').toLowerCase().includes(searchTerm)
      ) {
        score += 20
        matchedFields.push('type')
      }

      if (provider.id.toLowerCase() === searchTerm) {
        score += 200
        matchedFields.push('id')
      }

      const normalizedPhone = (provider.contact?.phone || '').replace(/\D/g, '')
      if (digits && normalizedPhone.includes(digits)) {
        score += 10
        matchedFields.push('phone')
      }

      if (hasVerifiedSelfReferral(provider) && score > 0) {
        score += 10
      }

      if (queryCareFocuses.length > 0 && providerHasCareFocus(provider, queryCareFocuses)) {
        score += 25
        matchedFields.push('care_focus')
      }

      return { ...provider, searchScore: score, matchedFields }
    })
    .filter(provider => provider.searchScore > 0)
    .sort((a, b) => b.searchScore - a.searchScore)
    .slice(0, limit)

  if (results.length > 0) {
    return { results, suggestions: [] }
  }

  const suggestionRows = await d1All(
    `SELECT name, specialty_json FROM providers
     WHERE LOWER(name) LIKE ? OR specialty_text LIKE ?
     LIMIT 40`,
    [like, like]
  )

  const suggestions = new Set()
  for (const row of suggestionRows) {
    if (row.name) suggestions.add(row.name)
    const specialties = parseJsonSafe(row.specialty_json, [])
    if (Array.isArray(specialties)) {
      for (const specialty of specialties) {
        if (typeof specialty === 'string' && specialty.toLowerCase().includes(searchTerm)) {
          suggestions.add(specialty)
        }
      }
    }
  }

  const commonTerms = [
    'vårdcentral',
    'mottagning',
    'sjukhus',
    'klinik',
    'hälsocentral',
    'dermatologi',
    'ortopedi',
    'kardiologi',
    'neurologi',
    'psykiatri',
    'gynekologi',
    'urologi',
    'ögon',
    'önh',
    'tandvård'
  ]

  for (const term of commonTerms) {
    if (term.includes(searchTerm) || searchTerm.includes(term.slice(0, 3))) {
      suggestions.add(term)
    }
  }

  return { results: [], suggestions: Array.from(suggestions).slice(0, 5) }
}
