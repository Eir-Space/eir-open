import { useState } from 'react'
import { CARE_FOCUS_LABELS } from '../lib/care-focus'

const TYPE_LABELS = {
  all: 'All types',
  primary_care: 'Primary care',
  specialist: 'Specialists',
  hospital: 'Hospitals',
  dental: 'Dental',
  emergency: 'Emergency',
  mental_health: 'Mental health',
  pediatric: 'Pediatric',
  maternity: 'Maternity',
  other: 'Other'
}

const TYPE_ICONS = {
  all: '🏥',
  primary_care: '🩺',
  specialist: '👨‍⚕️',
  hospital: '🏨',
  dental: '🦷',
  emergency: '🚑',
  mental_health: '🧠',
  pediatric: '👶',
  maternity: '🤱',
  other: '📋'
}

const DEFAULT_SERVICE_FILTERS = {
  selfReferral: false,
  videoConsultation: false,
  mvkServices: false
}

export default function FilterPanel({
  selectedType,
  onTypeFilter,
  statistics,
  serviceFilters = DEFAULT_SERVICE_FILTERS,
  onServiceFiltersChange,
  careFocusFilters = [],
  onCareFocusFiltersChange
}) {
  const [showAdvanced, setShowAdvanced] = useState(false)

  const sortedTypes = Object.entries(statistics.by_type || {})
    .sort(([, a], [, b]) => b - a)
    .map(([type, count]) => ({ type, count }))
  const sortedFocuses = Object.entries(statistics.by_focus || {})
    .filter(([focus]) => focus !== 'general')
    .sort(([, a], [, b]) => b - a)
    .map(([focus, count]) => ({ focus, count }))

  const toggleServiceFilter = filterName => {
    if (!onServiceFiltersChange) return
    onServiceFiltersChange({
      ...serviceFilters,
      [filterName]: !serviceFilters[filterName]
    })
  }

  const toggleCareFocus = focus => {
    if (!onCareFocusFiltersChange) return
    const exists = careFocusFilters.includes(focus)
    onCareFocusFiltersChange(
      exists
        ? careFocusFilters.filter(item => item !== focus)
        : [...careFocusFilters, focus]
    )
  }

  return (
    <div className="filter-panel">
      <div className="filter-header">
        <h2>Filters</h2>
      </div>

      <div className="filter-section">
        <h3>Provider type</h3>
        <div className="filter-types">
          <button
            type="button"
            className={`type-filter ${selectedType === 'all' ? 'active' : ''}`}
            onClick={() => onTypeFilter('all')}
          >
            <span className="filter-icon">{TYPE_ICONS.all}</span>
            <span className="filter-label">{TYPE_LABELS.all}</span>
            <span className="filter-count">{statistics.total?.toLocaleString() || '0'}</span>
          </button>

          {sortedTypes.map(({ type, count }) => (
            <button
              key={type}
              type="button"
              className={`type-filter ${selectedType === type ? 'active' : ''}`}
              onClick={() => onTypeFilter(type)}
            >
              <span className="filter-icon">{TYPE_ICONS[type] || TYPE_ICONS.other}</span>
              <span className="filter-label">{TYPE_LABELS[type] || type}</span>
              <span className="filter-count">{count.toLocaleString()}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="filter-section">
        <button className="advanced-toggle" type="button" onClick={() => setShowAdvanced(!showAdvanced)}>
          <span>Service filters</span>
          <span className={`toggle-icon ${showAdvanced ? 'open' : ''}`}>▼</span>
        </button>

        {showAdvanced && (
          <div className="advanced-filters">
            <label className="filter-checkbox">
              <input
                type="checkbox"
                checked={serviceFilters.selfReferral}
                onChange={() => toggleServiceFilter('selfReferral')}
              />
              <span className="checkbox-label">Accepts self-referrals</span>
            </label>

            <label className="filter-checkbox">
              <input
                type="checkbox"
                checked={serviceFilters.videoConsultation}
                onChange={() => toggleServiceFilter('videoConsultation')}
              />
              <span className="checkbox-label">
                Video consultation ({(statistics.with_video_consultation || 0).toLocaleString()})
              </span>
            </label>

            <label className="filter-checkbox">
              <input
                type="checkbox"
                checked={serviceFilters.mvkServices}
                onChange={() => toggleServiceFilter('mvkServices')}
              />
              <span className="checkbox-label">
                MVK services ({(statistics.with_mvk_services || 0).toLocaleString()})
              </span>
            </label>
          </div>
        )}
      </div>

      <div className="filter-section">
        <h3>Care focus</h3>
        <div className="focus-filters">
          {sortedFocuses.slice(0, 12).map(({ focus, count }) => (
            <button
              key={focus}
              type="button"
              className={`focus-filter ${careFocusFilters.includes(focus) ? 'active' : ''}`}
              onClick={() => toggleCareFocus(focus)}
            >
              <span>{CARE_FOCUS_LABELS[focus] || focus}</span>
              <span className="filter-count">{count.toLocaleString()}</span>
            </button>
          ))}
        </div>
      </div>

      {(selectedType !== 'all' || Object.values(serviceFilters).some(Boolean) || careFocusFilters.length > 0) && (
        <div className="filter-summary">
          <div className="active-filters">
            {selectedType !== 'all' && (
              <span className="active-filter">
                {TYPE_LABELS[selectedType]}
                <button type="button" onClick={() => onTypeFilter('all')}>✕</button>
              </span>
            )}
            {serviceFilters.selfReferral && (
              <span className="active-filter">
                Self-referral
                <button type="button" onClick={() => toggleServiceFilter('selfReferral')}>✕</button>
              </span>
            )}
            {serviceFilters.videoConsultation && (
              <span className="active-filter">
                Video
                <button type="button" onClick={() => toggleServiceFilter('videoConsultation')}>✕</button>
              </span>
            )}
            {serviceFilters.mvkServices && (
              <span className="active-filter">
                MVK
                <button type="button" onClick={() => toggleServiceFilter('mvkServices')}>✕</button>
              </span>
            )}
            {careFocusFilters.map(focus => (
              <span key={focus} className="active-filter">
                {CARE_FOCUS_LABELS[focus] || focus}
                <button type="button" onClick={() => toggleCareFocus(focus)}>✕</button>
              </span>
            ))}
          </div>
          <button
            className="clear-filters-btn"
            type="button"
            onClick={() => {
              onTypeFilter('all')
              onServiceFiltersChange?.(DEFAULT_SERVICE_FILTERS)
              onCareFocusFiltersChange?.([])
            }}
          >
            Reset
          </button>
        </div>
      )}

      <div className="filter-stats">
        <div className="stats-grid">
          <div className="stat-item">
            <span className="stat-number">{(statistics.with_coordinates || 0).toLocaleString()}</span>
            <span className="stat-label">Mapped</span>
          </div>
          <div className="stat-item">
            <span className="stat-number">{(statistics.with_phone || 0).toLocaleString()}</span>
            <span className="stat-label">With phone</span>
          </div>
          <div className="stat-item">
            <span className="stat-number">{(statistics.self_referral_eligible || 0).toLocaleString()}</span>
            <span className="stat-label">Self-referral</span>
          </div>
        </div>
      </div>
    </div>
  )
}
