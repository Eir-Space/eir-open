import { useEffect, useMemo, useState } from 'react'
import { List } from 'react-window'
import { distanceFromUser } from '../lib/distance'
import {
  getSelfReferralVerificationLabel,
  getSelfReferralVerificationStatus,
  hasVerifiedSelfReferral
} from '../lib/self-referral'

const ROW_HEIGHT = 96

export default function ProviderList({ providers, onProviderSelect, selectedProvider, userLocation }) {
  const [sortBy, setSortBy] = useState('name')
  const [sortOrder, setSortOrder] = useState('asc')
  const [listHeight, setListHeight] = useState(600)

  useEffect(() => {
    const updateHeight = () => {
      const next = Math.max(320, window.innerHeight - 300)
      setListHeight(next)
    }
    updateHeight()
    window.addEventListener('resize', updateHeight)
    return () => window.removeEventListener('resize', updateHeight)
  }, [])

  const sortedProviders = useMemo(() => {
    return [...providers].sort((a, b) => {
      const aName = a.name.toLowerCase()
      const bName = b.name.toLowerCase()
      const aType = a.type || 'other'
      const bType = b.type || 'other'
      const aLocation = (a.location?.address || '').toLowerCase()
      const bLocation = (b.location?.address || '').toLowerCase()

      let lhs = aName
      let rhs = bName
      if (sortBy === 'type') {
        lhs = aType
        rhs = bType
      }
      if (sortBy === 'location') {
        lhs = aLocation
        rhs = bLocation
      }
      if (sortBy === 'distance') {
        lhs = distanceFromUser(a, userLocation)
        rhs = distanceFromUser(b, userLocation)
      }

      if (lhs < rhs) return sortOrder === 'asc' ? -1 : 1
      if (lhs > rhs) return sortOrder === 'asc' ? 1 : -1
      return 0
    })
  }, [providers, sortBy, sortOrder, userLocation])

  const handleSort = field => {
    if (field === sortBy) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')
      return
    }
    setSortBy(field)
    setSortOrder('asc')
  }

  if (sortedProviders.length === 0) {
    return (
      <section className="provider-list-panel provider-list-empty">
        <h3>No providers found</h3>
        <p>Adjust your filters or search query.</p>
      </section>
    )
  }

  return (
    <section className="provider-list-panel">
      <div className="list-toolbar">
        <p>{sortedProviders.length.toLocaleString()} providers</p>
        <div className="segmented">
          <button
            className={sortBy === 'name' ? 'active' : ''}
            onClick={() => handleSort('name')}
            type="button"
          >
            Name
          </button>
          <button
            className={sortBy === 'type' ? 'active' : ''}
            onClick={() => handleSort('type')}
            type="button"
          >
            Type
          </button>
          <button
            className={sortBy === 'location' ? 'active' : ''}
            onClick={() => handleSort('location')}
            type="button"
          >
            Location
          </button>
          {userLocation && (
            <button
              className={sortBy === 'distance' ? 'active' : ''}
              onClick={() => handleSort('distance')}
              type="button"
            >
              Distance
            </button>
          )}
        </div>
      </div>

      <List
        className="virtual-list"
        rowComponent={ProviderRow}
        rowCount={sortedProviders.length}
        rowHeight={ROW_HEIGHT}
        rowProps={{
          providers: sortedProviders,
          selectedId: selectedProvider?.id,
          onProviderSelect,
          userLocation
        }}
        style={{ height: listHeight }}
        defaultHeight={600}
      />
    </section>
  )
}

function ProviderRow({ index, style, providers, selectedId, onProviderSelect, userLocation }) {
  const provider = providers[index]
  const isSelected = selectedId === provider.id
  const distance = userLocation ? distanceFromUser(provider, userLocation) : null
  const verificationStatus = getSelfReferralVerificationStatus(provider)
  const verificationLabel = getSelfReferralVerificationLabel(provider)

  return (
    <div style={style} className="virtual-row-wrap">
      <button
        type="button"
        className={`provider-row ${isSelected ? 'selected' : ''}`}
        onClick={() => onProviderSelect(provider)}
      >
        <div className="provider-row-main">
          <h3>{provider.name}</h3>
          <p>{provider.location?.address || 'Address unavailable'}</p>
        </div>
        <div className="provider-row-meta">
          <span className={`type-pill ${provider.type}`}>{provider.type.replace('_', ' ')}</span>
          {typeof distance === 'number' && Number.isFinite(distance) && (
            <span className="distance-pill">{distance.toFixed(1)} km</span>
          )}
          {hasVerifiedSelfReferral(provider) && <span className="self-pill">Self referral</span>}
          <span className={`verification-pill ${verificationStatus}`} title={verificationLabel}>
            {verificationStatus === 'verified_yes' && '1177 verified'}
            {verificationStatus === 'verified_no' && '1177 checked'}
            {verificationStatus === 'unresolved' && '1177 pending'}
            {verificationStatus === 'unchecked' && '1177 not checked'}
          </span>
        </div>
      </button>
    </div>
  )
}
