import { useState, useEffect, useRef } from 'react'
import Head from 'next/head'
import dynamic from 'next/dynamic'
import SearchBar from '../components/SearchBar'
import FilterPanel from '../components/FilterPanel'
import { filterProviders } from '../lib/provider-filters'
import { getProviderDescription } from '../lib/provider-description'
import {
  getSelfReferralVerificationLabel,
  getSelfReferralVerificationStatus,
  hasVerifiedSelfReferral
} from '../lib/self-referral'
import { CARE_FOCUS_LABELS, deriveProviderCareFocuses } from '../lib/care-focus'
import { hasMVKServices, hasVideoConsultation } from '../lib/service-capabilities'

const ProviderMap = dynamic(() => import('../components/ProviderMap'), { ssr: false })
const ProviderList = dynamic(() => import('../components/ProviderList'), { ssr: false })

const EMPTY_STATS = {
  total: 0,
  by_type: {},
  by_focus: {},
  with_coordinates: 0,
  with_phone: 0,
  with_video_consultation: 0,
  with_mvk_services: 0,
  self_referral_eligible: 0,
  with_address: 0
}

export default function Home() {
  const [providers, setProviders] = useState([])
  const [filteredProviders, setFilteredProviders] = useState([])
  const [datasetMetadata, setDatasetMetadata] = useState({
    total_providers: 0,
    generated: new Date().toISOString()
  })
  const [statistics, setStatistics] = useState(EMPTY_STATS)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedType, setSelectedType] = useState('all')
  const [serviceFilters, setServiceFilters] = useState({
    selfReferral: false,
    videoConsultation: false,
    mvkServices: false
  })
  const [careFocusFilters, setCareFocusFilters] = useState([])
  const [loading, setLoading] = useState(true)
  const [loadingError, setLoadingError] = useState('')
  const [viewMode, setViewMode] = useState('map')
  const [selectedProvider, setSelectedProvider] = useState(null)
  const [userLocation, setUserLocation] = useState(null)
  const [locationStatus, setLocationStatus] = useState('')
  const [providerDescription, setProviderDescription] = useState('')
  const [providerDescriptionLoading, setProviderDescriptionLoading] = useState(false)
  const [providerInsights, setProviderInsights] = useState({
    supportsSelfReferral: false,
    eServices: [],
    actions: []
  })
  const [liveInsightsStatus, setLiveInsightsStatus] = useState('idle')
  const [nearbyOnly, setNearbyOnly] = useState(false)
  const [nearbyRadiusKm, setNearbyRadiusKm] = useState(25)
  const descriptionCacheRef = useRef(new Map())
  const [locationFocusSeq, setLocationFocusSeq] = useState(0)
  const [digitalOnlyProviders, setDigitalOnlyProviders] = useState([])
  const selectedProviderVerificationStatus = selectedProvider
    ? getSelfReferralVerificationStatus(selectedProvider)
    : 'unchecked'
  const selectedProviderVerificationLabel = selectedProvider
    ? getSelfReferralVerificationLabel(selectedProvider)
    : ''

  // Load provider data on mount
  useEffect(() => {
    let cancelled = false

    const fetchProviderChunk = async (offset, limit) => {
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 20000)
      try {
        const response = await fetch(
          `/api/providers?limit=${limit}&offset=${offset}&summary=true`,
          { signal: controller.signal }
        )
        if (!response.ok) {
          throw new Error(`Provider API returned ${response.status}`)
        }
        return response.json()
      } finally {
        clearTimeout(timeoutId)
      }
    }

    const loadRemainingProviders = async (startOffset, totalProviders) => {
      const chunkSize = 5000
      for (let offset = startOffset; offset < totalProviders; offset += chunkSize) {
        if (cancelled) return
        try {
          const data = await fetchProviderChunk(offset, chunkSize)
          const chunk = data.providers || []
          if (!chunk.length) break
          if (cancelled) return
          setProviders(prev => prev.concat(chunk))
        } catch (error) {
          console.error('Error loading remaining providers:', error)
          return
        }
      }
    }

    async function loadProviders() {
      let initialLoaded = false
      try {
        setLoading(true)
        setLoadingError('')
        const data = await fetchProviderChunk(0, 5000)
        const loadedProviders = data.providers || []
        if (cancelled) return

        setProviders(loadedProviders)
        setFilteredProviders(loadedProviders)
        setStatistics(calculateStatistics(loadedProviders))

        const totalProviders = data.metadata?.total || loadedProviders.length
        setDatasetMetadata({
          total_providers: totalProviders,
          generated: new Date().toISOString()
        })
        initialLoaded = true
        setLoading(false)

        if (loadedProviders.length < totalProviders) {
          void loadRemainingProviders(loadedProviders.length, totalProviders)
        }
      } catch (error) {
        if (cancelled) return
        console.error('Error loading providers:', error)
        setLoadingError('Could not load provider data. Please retry.')
      } finally {
        if (!cancelled && !initialLoaded) {
          setLoading(false)
        }
      }
    }
    
    loadProviders()
    return () => {
      cancelled = true
    }
  }, [])

  // Filter providers when search or filters change.
  useEffect(() => {
    const baseFiltered = filterProviders(providers, {
      selectedType,
      searchQuery,
      serviceFilters,
      careFocusFilters,
      userLocation,
      nearbyOnly,
      nearbyRadiusKm
    })

    const withAddress = baseFiltered.filter(provider => hasAddress(provider))
    const digitalOnly = baseFiltered.filter(
      provider =>
        !hasAddress(provider) &&
        (provider.services?.video_consultation || provider.contact?.website)
    )

    setFilteredProviders(withAddress)
    setDigitalOnlyProviders(digitalOnly)
  }, [providers, searchQuery, selectedType, serviceFilters, careFocusFilters, userLocation, nearbyOnly, nearbyRadiusKm])

  useEffect(() => {
    setStatistics(calculateStatistics(providers))
  }, [providers])

  // Clear selected provider if it disappears from filtered result set.
  useEffect(() => {
    if (!selectedProvider) return
    const exists =
      filteredProviders.some(provider => provider.id === selectedProvider.id) ||
      digitalOnlyProviders.some(provider => provider.id === selectedProvider.id)
    if (!exists) {
      setSelectedProvider(null)
    }
  }, [filteredProviders, digitalOnlyProviders, selectedProvider])

  const handleSearch = (query) => {
    setSearchQuery(query)
  }

  const handleTypeFilter = (type) => {
    setSelectedType(type)
  }

  const handleServiceFiltersChange = (nextFilters) => {
    setServiceFilters(nextFilters)
  }

  const handleCareFocusFiltersChange = (nextFilters) => {
    setCareFocusFilters(nextFilters)
  }

  const handleProviderSelect = (provider) => {
    setSelectedProvider(provider)
  }

  const applySelfReferralSpecialistsShortcut = () => {
    applyShortcut({
      query: '',
      type: 'specialist',
      services: { ...serviceFilters, selfReferral: true },
      mode: 'list'
    })
  }

  const applyShortcut = ({
    query = '',
    type = 'all',
    services = null,
    careFocuses = [],
    requireNearby = false,
    mode = 'map'
  }) => {
    setSearchQuery(query)
    setSelectedType(type)
    if (services) {
      setServiceFilters(services)
    }
    setCareFocusFilters(careFocuses)
    if (requireNearby && userLocation) {
      setNearbyOnly(true)
    }
    setViewMode(mode)
  }

  useEffect(() => {
    const parseBooleanFlag = value =>
      ['1', 'true', 'yes', 'on'].includes(String(value || '').toLowerCase())

    const search = new URLSearchParams(window.location.search)
    const shortcut = (search.get('shortcut') || '').toLowerCase()

    const useSelfReferralShortcut =
      parseBooleanFlag(search.get('self_referral_specialists')) ||
      parseBooleanFlag(search.get('self_referral_verified')) ||
      shortcut === 'self-referral-specialists' ||
      shortcut === 'self_referral_specialists'

    if (useSelfReferralShortcut) {
      applySelfReferralSpecialistsShortcut()
    }
  }, [])

  const handleUseCurrentLocation = () => {
    if (userLocation) {
      setViewMode('map')
      setLocationFocusSeq(value => value + 1)
      setLocationStatus('Centered on your location.')
      return
    }

    if (!navigator.geolocation) {
      setLocationStatus('Geolocation is not supported in this browser.')
      return
    }

    setLocationStatus('Locating you...')
    navigator.geolocation.getCurrentPosition(
      position => {
        setUserLocation({
          lat: position.coords.latitude,
          lng: position.coords.longitude
        })
        setViewMode('map')
        setNearbyOnly(true)
        setLocationFocusSeq(value => value + 1)
        setLocationStatus('Using your current location.')
      },
      () => {
        setLocationStatus('Could not access your location. Check browser permissions.')
      },
      { enableHighAccuracy: true, timeout: 12000 }
    )
  }

  useEffect(() => {
    setProviderDescriptionLoading(false)
    setLiveInsightsStatus('idle')
    if (!selectedProvider) {
      setProviderDescription('')
      setProviderInsights({ supportsSelfReferral: false, eServices: [], actions: [] })
      return
    }

    const localDescription = getProviderDescription(selectedProvider)
    const localEServices = normalizeProviderEServices(selectedProvider)
    const localActions = normalizeProviderActions(selectedProvider)
    setProviderDescription(localDescription || '')
    setProviderInsights({
      supportsSelfReferral: hasVerifiedSelfReferral(selectedProvider),
      eServices: localEServices,
      actions: localActions
    })
  }, [selectedProvider])

  const handleLoadLiveDetails = async () => {
    const provider = selectedProvider
    const url = provider?.contact?.website
    if (!provider || !url) return

    const localDescription = getProviderDescription(provider)
    const localEServices = normalizeProviderEServices(provider)
    const localActions = normalizeProviderActions(provider)

    if (descriptionCacheRef.current.has(url)) {
      const cached = descriptionCacheRef.current.get(url)
      setProviderDescription(cached.description || localDescription || '')
      setProviderInsights({
        supportsSelfReferral: Boolean(cached.supportsSelfReferral) || hasVerifiedSelfReferral(provider),
        eServices: mergeEServices(cached.eServices || [], localEServices),
        actions: mergeActions(cached.actions || [], localActions)
      })
      setLiveInsightsStatus('loaded')
      return
    }

    setProviderDescriptionLoading(true)
    setLiveInsightsStatus('loading')

    try {
      const response = await fetch(
        `/api/provider-description?allow_live=true&url=${encodeURIComponent(url)}`
      )
      const data = await response.json()
      descriptionCacheRef.current.set(url, data)

      if (data.rateLimited) {
        setLiveInsightsStatus('rate_limited')
      } else if (data.liveFetchDisabled) {
        setLiveInsightsStatus('disabled')
      } else {
        setLiveInsightsStatus('loaded')
      }

      setProviderDescription(
        data.description && data.description.length > (localDescription || '').length
          ? data.description
          : localDescription || ''
      )
      setProviderInsights({
        supportsSelfReferral: Boolean(data.supportsSelfReferral) || hasVerifiedSelfReferral(provider),
        eServices: mergeEServices(data.eServices || [], localEServices),
        actions: mergeActions(data.actions || [], localActions)
      })
    } catch {
      setLiveInsightsStatus('error')
      setProviderDescription(localDescription || '')
      setProviderInsights({
        supportsSelfReferral: hasVerifiedSelfReferral(provider),
        eServices: localEServices,
        actions: localActions
      })
    } finally {
      setProviderDescriptionLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="loading-container">
        <Head>
          <title>EIR Provider Directory - Loading...</title>
        </Head>
        <div className="loading-spinner">
          <h2>🏥 Loading Swedish Healthcare Providers...</h2>
          <div className="spinner"></div>
        </div>
      </div>
    )
  }

  if (!loading && loadingError) {
    return (
      <div className="loading-container">
        <Head>
          <title>EIR Provider Directory - Error</title>
        </Head>
        <div className="loading-spinner">
          <h2>Could not load provider data</h2>
          <p>{loadingError}</p>
          <button className="my-location-button" onClick={() => window.location.reload()}>
            Retry
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="app-container">
      <Head>
        <title>EIR Provider Directory</title>
        <meta name="description" content="World-class healthcare provider search. Starting with Sweden." />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <header className="app-header">
        <div>
          <p className="kicker">EIR Open • Provider Directory</p>
          <h1>Find the right healthcare provider fast</h1>
          <p className="header-subtitle">
            Built for speed, trust, and clarity. Sweden today, global coverage next.
          </p>
        </div>
        <div className="header-stats">
          <strong>{filteredProviders.length.toLocaleString()}</strong>
          <span>matches</span>
          <span className="muted">from {datasetMetadata.total_providers.toLocaleString()} providers</span>
        </div>
      </header>

      <section className="controls-shell">
        <div className="top-controls">
          <SearchBar
            onSearch={handleSearch}
            placeholder="Search by provider, specialty, city, or address..."
            value={searchQuery}
          />
          <div className="segmented view-toggle">
            <button
              className={viewMode === 'map' ? 'active' : ''}
              onClick={() => setViewMode('map')}
              type="button"
            >
              Map
            </button>
            <button
              className={viewMode === 'list' ? 'active' : ''}
              onClick={() => setViewMode('list')}
              type="button"
            >
              List
            </button>
          </div>
          <button
            className="ghost-btn my-position-btn"
            type="button"
            onClick={handleUseCurrentLocation}
            title="Get and center on your location"
            aria-label="My Position"
          >
            My Position
          </button>
        </div>
        <div className="result-hint">
          {searchQuery ? `Searching for "${searchQuery}"` : 'Showing all providers'}
          {selectedType !== 'all' && ` · ${selectedType.replace('_', ' ')}`}
          {careFocusFilters.length > 0 &&
            ` · ${careFocusFilters.map(focus => CARE_FOCUS_LABELS[focus] || focus).join(', ')}`}
          {nearbyOnly && userLocation && ` · within ${nearbyRadiusKm} km`}
          {locationStatus && ` · ${locationStatus}`}
        </div>
        {userLocation && (
          <div className="nearby-controls">
            <label htmlFor="nearby-only">
              <input
                id="nearby-only"
                type="checkbox"
                checked={nearbyOnly}
                onChange={event => setNearbyOnly(event.target.checked)}
              />
              Nearby only
            </label>
            <label htmlFor="radius">
              Radius
              <select
                id="radius"
                value={nearbyRadiusKm}
                onChange={event => setNearbyRadiusKm(parseInt(event.target.value, 10))}
              >
                <option value={5}>5 km</option>
                <option value={10}>10 km</option>
                <option value={25}>25 km</option>
                <option value={50}>50 km</option>
                <option value={100}>100 km</option>
              </select>
            </label>
          </div>
        )}
      </section>

      <section className="care-shortcuts">
        <div className="care-shortcuts__header">
          <h2>What do you need help with?</h2>
          <button
            type="button"
            className="ghost-btn"
            onClick={() =>
              applyShortcut({
                query: '',
                type: 'all',
                services: { selfReferral: false, videoConsultation: false, mvkServices: false },
                careFocuses: [],
                mode: 'map'
              })
            }
          >
            Reset choices
          </button>
        </div>
        <div className="care-shortcuts__grid">
          <button
            type="button"
            className="shortcut-btn"
            onClick={() =>
              applyShortcut({
                query: 'vårdcentral',
                type: 'primary_care',
                mode: 'list',
                requireNearby: true
              })
            }
          >
            <strong>Nearest primary care</strong>
            <span>Best when you need non-emergency care quickly.</span>
          </button>
          <button
            type="button"
            className="shortcut-btn"
            onClick={applySelfReferralSpecialistsShortcut}
          >
            <strong>Self-referral specialists</strong>
            <span>Find clinics where you can contact directly.</span>
          </button>
          <button
            type="button"
            className="shortcut-btn"
            onClick={() =>
              applyShortcut({
                query: '',
                type: 'all',
                services: { ...serviceFilters, videoConsultation: true },
                mode: 'list'
              })
            }
          >
            <strong>Digital consultation</strong>
            <span>Online-first providers and video care options.</span>
          </button>
          <button
            type="button"
            className="shortcut-btn"
            onClick={() =>
              applyShortcut({
                query: 'psykiatri',
                type: 'mental_health',
                careFocuses: ['mental-health'],
                mode: 'list'
              })
            }
          >
            <strong>Mental health support</strong>
            <span>Psychiatry and mental health related care.</span>
          </button>
        </div>
      </section>

      <div className="safety-banner">
        <strong>Need urgent help?</strong> For life-threatening symptoms in Sweden, call <a href="tel:112">112</a>.
      </div>

      <main className="workspace-grid">
        <aside className="sidebar-panel">
          <FilterPanel
            selectedType={selectedType}
            onTypeFilter={handleTypeFilter}
            serviceFilters={serviceFilters}
            onServiceFiltersChange={handleServiceFiltersChange}
            careFocusFilters={careFocusFilters}
            onCareFocusFiltersChange={handleCareFocusFiltersChange}
            statistics={statistics}
          />
          <section className="digital-clinics-panel">
            <h3>Digital-only clinics</h3>
            {digitalOnlyProviders.length === 0 ? (
              <p>No digital-only clinics in current filters.</p>
            ) : (
              <div className="digital-clinics-list">
                {digitalOnlyProviders.slice(0, 30).map(provider => (
                  <button
                    key={provider.id}
                    type="button"
                    className="digital-clinic-item"
                    onClick={() => handleProviderSelect(provider)}
                  >
                    <strong>{provider.name}</strong>
                    <span>{provider.contact?.website ? 'Online clinic profile available' : 'Digital care'}</span>
                  </button>
                ))}
              </div>
            )}
          </section>
        </aside>
        <section className="content-panel">
        {viewMode === 'map' ? (
          <ProviderMap
            providers={filteredProviders}
            onProviderSelect={handleProviderSelect}
            selectedProvider={selectedProvider}
            userLocation={userLocation}
            locationFocusSeq={locationFocusSeq}
          />
        ) : (
          <ProviderList 
            providers={filteredProviders}
            onProviderSelect={handleProviderSelect}
            selectedProvider={selectedProvider}
            userLocation={userLocation}
          />
        )}
        </section>
      </main>

      {filteredProviders.length === 0 && (
        <section className="no-results-help">
          <h3>No clinics matched your current filters</h3>
          <p>Try broadening your search, disabling Nearby only, or using a shortcut above.</p>
          <p>
            If you are unsure where to start in Sweden, call <a href="tel:1177">1177</a> for healthcare guidance.
          </p>
        </section>
      )}

      {selectedProvider && (
        <aside className="provider-details-overlay">
          <div className="provider-details">
            <div className="provider-header">
              <h3>{selectedProvider.name}</h3>
              <button
                className="close-button"
                onClick={() => setSelectedProvider(null)}
                type="button"
              >
                ✕
              </button>
            </div>

            <div className="provider-info">
              <div className="provider-type">
                <span className={`type-badge ${selectedProvider.type}`}>
                  {selectedProvider.type.replace('_', ' ')}
                </span>
                <span
                  className={`verification-pill ${selectedProviderVerificationStatus}`}
                  title={selectedProviderVerificationLabel}
                >
                  {selectedProviderVerificationStatus === 'verified_yes' && '1177: self-referral verified'}
                  {selectedProviderVerificationStatus === 'verified_no' && '1177: no self-referral'}
                  {selectedProviderVerificationStatus === 'unresolved' && '1177: verification pending'}
                  {selectedProviderVerificationStatus === 'unchecked' && '1177: not checked'}
                </span>
                {(hasVerifiedSelfReferral(selectedProvider) || providerInsights.supportsSelfReferral) && (
                  <span className="eigen-remiss-badge">Egen remiss OK</span>
                )}
              </div>

              {selectedProvider.specialty.length > 0 && (
                <div className="specialties">
                  <strong>Specialties:</strong> {selectedProvider.specialty.join(', ')}
                </div>
              )}

              {selectedProvider.contact.website && (
                <div className="live-details">
                  <button
                    type="button"
                    className="ghost-btn"
                    onClick={handleLoadLiveDetails}
                    disabled={providerDescriptionLoading}
                  >
                    {providerDescriptionLoading ? 'Loading live 1177 details...' : 'Load live 1177 details'}
                  </button>
                  {liveInsightsStatus === 'rate_limited' && (
                    <p className="live-details-note">1177 is rate-limiting requests right now.</p>
                  )}
                  {liveInsightsStatus === 'error' && (
                    <p className="live-details-note">Could not load live details. Local data is still shown.</p>
                  )}
                </div>
              )}

              {(providerDescriptionLoading || providerDescription) && (
                <div className="description">
                  <strong>About this provider:</strong>
                  <p>{providerDescriptionLoading ? 'Loading description...' : providerDescription}</p>
                </div>
              )}

              {selectedProvider.location.address && (
                <div className="address">
                  <strong>Address:</strong><br />
                  {selectedProvider.location.address}
                </div>
              )}

              {selectedProvider.contact.phone && (
                <div className="phone">
                  <strong>Phone:</strong><br />
                  <a href={`tel:${selectedProvider.contact.phone}`}>
                    {selectedProvider.contact.phone}
                  </a>
                </div>
              )}

              <div className="services">
                <strong>Services:</strong>
                <ul>
                  {(hasVerifiedSelfReferral(selectedProvider) || providerInsights.supportsSelfReferral) && 
                    <li>Accepts self-referrals</li>
                  }
                  {hasVideoConsultation(selectedProvider) && 
                    <li>Video consultation available</li>
                  }
                  {hasMVKServices(selectedProvider) && 
                    <li>MVK services available</li>
                  }
                </ul>
              </div>

              {providerInsights.actions.length > 0 && (
                <div className="eservices">
                  <strong>1177 actions you can perform:</strong>
                  <ul>
                    {providerInsights.actions.slice(0, 8).map(action => (
                      <li key={`${action.external_id || action.text}-${action.url || ''}`}>
                        {action.url ? (
                          <a href={action.url} target="_blank" rel="noopener noreferrer">
                            {action.text}
                          </a>
                        ) : (
                          action.text
                        )}
                        {action.heading && <span className="action-heading"> · {action.heading}</span>}
                        {action.description_text && (
                          <p className="action-description">{action.description_text}</p>
                        )}
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {providerInsights.actions.length === 0 && providerInsights.eServices.length > 0 && (
                <div className="eservices">
                  <strong>1177 e-services:</strong>
                  <ul>
                    {providerInsights.eServices.slice(0, 6).map(service => (
                      <li key={service.text}>
                        {service.url ? (
                          <a href={service.url} target="_blank" rel="noopener noreferrer">
                            {service.text}
                          </a>
                        ) : (
                          service.text
                        )}
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {selectedProvider.contact.website && (
                <div className="website">
                  <a 
                    href={selectedProvider.contact.website} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="website-link"
                  >
                    View on 1177.se →
                  </a>
                </div>
              )}

              <div className="metadata">
                <small>
                  HSA ID: {selectedProvider.id}<br />
                  Data source: {selectedProvider.metadata?.source || '1177.se'}
                </small>
              </div>
            </div>
          </div>
        </aside>
      )}

      <footer className="app-footer">
        <div className="footer-content">
          <p>
            <strong>EIR Provider Directory</strong> · Data source: 1177.se
          </p>
          <p>
            <small>
              {datasetMetadata.total_providers.toLocaleString()} providers •
              Last updated: {new Date(datasetMetadata.generated).toLocaleDateString()}
            </small>
          </p>
        </div>
      </footer>
    </div>
  )
}

function calculateStatistics(inputProviders) {
  const providers = inputProviders || []
  const byType = {}
  const byFocus = {}

  for (const provider of providers) {
    const type = provider.type || 'other'
    byType[type] = (byType[type] || 0) + 1

    const focuses = deriveProviderCareFocuses(provider)
    for (const focus of focuses) {
      byFocus[focus] = (byFocus[focus] || 0) + 1
    }
  }

  return {
    total: providers.length,
    by_type: byType,
    by_focus: byFocus,
    with_coordinates: providers.filter(provider => provider.location?.coordinates?.lat && provider.location?.coordinates?.lng).length,
    with_phone: providers.filter(provider => provider.contact?.phone).length,
    with_video_consultation: providers.filter(provider => hasVideoConsultation(provider)).length,
    with_mvk_services: providers.filter(provider => hasMVKServices(provider)).length,
    self_referral_eligible: providers.filter(provider => hasVerifiedSelfReferral(provider)).length,
    with_address: providers.filter(provider => provider.location?.address).length
  }
}

function hasAddress(provider) {
  const address = provider?.location?.address
  return typeof address === 'string' && address.trim().length > 0
}

function normalizeProviderEServices(provider) {
  const actions = normalizeProviderActions(provider)
  if (actions.length > 0) {
    return actions.map(action => ({
      text: action.text,
      url: action.url || ''
    }))
  }

  const rawServices = provider?.services?.e_services
  if (!Array.isArray(rawServices)) return []

  return rawServices
    .map(service => {
      if (typeof service === 'string') return { text: service, url: '' }
      return {
        text: service?.text || service?.Text || '',
        url: service?.url || service?.Url || ''
      }
    })
    .filter(service => service.text)
}

function mergeEServices(primary, secondary) {
  const merged = [...primary, ...secondary]
  const unique = new Map()
  for (const service of merged) {
    const key = (service?.text || '').toLowerCase()
    if (!key) continue
    if (!unique.has(key)) unique.set(key, service)
  }
  return Array.from(unique.values())
}

function normalizeProviderActions(provider) {
  const rawActions =
    provider?.services?.e_services_structured ||
    provider?.profile_1177?.actions ||
    []

  if (!Array.isArray(rawActions)) return []

  return rawActions
    .map(action => ({
      external_id: action?.external_id || action?.ExternalId || '',
      action_code: action?.action_code || '',
      text: action?.text || action?.Text || '',
      url: action?.url || action?.Url || '',
      heading: action?.heading || action?.Heading || '',
      description_text: action?.description_text || stripActionText(action?.description_html || action?.Description || ''),
      description_html: action?.description_html || action?.Description || ''
    }))
    .filter(action => action.text)
}

function mergeActions(primary, secondary) {
  const merged = [...primary, ...secondary]
  const unique = new Map()
  for (const action of merged) {
    const key = `${(action?.external_id || '').toLowerCase()}::${(action?.text || '').toLowerCase()}`
    if (!key.trim()) continue
    if (!unique.has(key)) unique.set(key, action)
  }
  return Array.from(unique.values())
}

function stripActionText(html) {
  if (typeof html !== 'string') return ''
  return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
}
