import { hasVerifiedSelfReferral } from '../../lib/self-referral'
import { loadProviderDataset } from '../../lib/provider-data'
import { getProvidersFromDatabase, hasProviderDatabase } from '../../lib/provider-db'

export default async function handler(req, res) {
  const { method, query } = req
  
  if (method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    if (hasProviderDatabase()) {
      try {
        const dbResult = await getProvidersFromDatabase(query)
        if (dbResult) {
          return res.status(200).json({
            metadata: {
              total: dbResult.total,
              returned: dbResult.providers.length,
              offset: parseInt(query.offset || 0),
              limit: parseInt(query.limit || 1000),
              filters_applied: {
                type: query.type || null,
                specialty: query.specialty || null,
                self_referral: query.self_referral === 'true' || null,
                location: query.location || null,
                geographic: !!(query.lat && query.lng)
              },
              source: 'd1'
            },
            providers: dbResult.providers
          })
        }
      } catch (dbError) {
        console.error('D1 providers query failed, falling back to dataset:', dbError)
      }
    }

    // Determine which dataset to use
    const useSample = query.sample === 'true'
    const data = await loadProviderDataset(req, { useSample })
    let providers = data.providers

    // Apply filters
    const { 
      type, 
      specialty,
      self_referral,
      location,
      lat,
      lng,
      radius = 50, // km
      limit = 1000,
      offset = 0
    } = query
    const summaryMode = query.summary !== 'false'

    // Filter by type
    if (type && type !== 'all') {
      providers = providers.filter(p => p.type === type)
    }

    // Filter by specialty
    if (specialty) {
      providers = providers.filter(p => 
        p.specialty.some(s => s.toLowerCase().includes(specialty.toLowerCase()))
      )
    }

    // Filter by self-referral capability
    if (self_referral === 'true') {
      providers = providers.filter(p => hasVerifiedSelfReferral(p))
    }

    // Geographic filtering (if lat/lng provided)
    if (lat && lng) {
      const centerLat = parseFloat(lat)
      const centerLng = parseFloat(lng)
      const maxRadius = parseFloat(radius)
      
      providers = providers.filter(provider => {
        const providerLat = provider.location.coordinates.lat
        const providerLng = provider.location.coordinates.lng
        
        if (!providerLat || !providerLng) return false
        
        // Simple distance calculation (Haversine formula)
        const distance = calculateDistance(centerLat, centerLng, providerLat, providerLng)
        return distance <= maxRadius
      }).map(provider => ({
        ...provider,
        distance: calculateDistance(centerLat, centerLng, 
          provider.location.coordinates.lat, 
          provider.location.coordinates.lng
        )
      })).sort((a, b) => a.distance - b.distance)
    }

    // Text search in location
    if (location) {
      const searchTerm = location.toLowerCase()
      providers = providers.filter(p => 
        (p.location.address && p.location.address.toLowerCase().includes(searchTerm)) ||
        p.name.toLowerCase().includes(searchTerm)
      )
    }

    // Pagination
    const startIndex = parseInt(offset)
    const endIndex = startIndex + parseInt(limit)
    let paginatedProviders = providers.slice(startIndex, endIndex)

    if (summaryMode) {
      paginatedProviders = paginatedProviders.map(toSummaryProvider)
    }

    // Response
    res.status(200).json({
      metadata: {
        total: providers.length,
        returned: paginatedProviders.length,
        offset: startIndex,
        limit: parseInt(limit),
        filters_applied: {
          type: type || null,
          specialty: specialty || null,
          self_referral: self_referral === 'true' || null,
          location: location || null,
          geographic: !!(lat && lng)
        }
      },
      providers: paginatedProviders
    })

  } catch (error) {
    console.error('Error serving providers:', error)
    res.status(500).json({ error: 'Internal server error' })
  }
}

// Calculate distance between two coordinates using Haversine formula
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371 // Earth's radius in kilometers
  const dLat = toRadians(lat2 - lat1)
  const dLng = toRadians(lng2 - lng1)
  
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLng/2) * Math.sin(dLng/2)
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  return R * c
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180)
}

function toSummaryProvider(provider) {
  const services = provider.services || {}
  return {
    id: provider.id,
    name: provider.name,
    type: provider.type,
    specialty: Array.isArray(provider.specialty) ? provider.specialty : [],
    contact: provider.contact || {},
    location: provider.location || {},
    services: {
      self_referral: Boolean(services.self_referral),
      self_referral_verified: Boolean(services.self_referral_verified),
      self_referral_verification_status:
        services.self_referral_verification_status || 'unchecked',
      video_consultation: Boolean(services.video_consultation),
      mvk_services: Boolean(services.mvk_services),
      has_listing: Boolean(services.has_listing),
      e_services: Array.isArray(services.e_services) ? services.e_services.slice(0, 12) : []
    },
    metadata: provider.metadata || {}
  }
}
