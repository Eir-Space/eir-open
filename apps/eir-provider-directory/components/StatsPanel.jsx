export default function StatsPanel({ statistics }) {
  const formatNumber = (num) => {
    if (!num) return '0'
    return num.toLocaleString()
  }

  const calculatePercentage = (part, total) => {
    if (!part || !total) return '0'
    return ((part / total) * 100).toFixed(1)
  }

  return (
    <div className="stats-panel">
      <h3>Database Statistics</h3>
      
      <div className="stats-overview">
        <div className="main-stat">
          <span className="stat-number-large">{formatNumber(statistics.total)}</span>
          <span className="stat-label-large">Total Healthcare Providers</span>
        </div>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-header">
            <span className="stat-icon">📍</span>
            <span className="stat-title">Geographic Coverage</span>
          </div>
          <div className="stat-number">{formatNumber(statistics.with_coordinates)}</div>
          <div className="stat-subtitle">
            {calculatePercentage(statistics.with_coordinates, statistics.total)}% with GPS coordinates
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-header">
            <span className="stat-icon">📞</span>
            <span className="stat-title">Contact Information</span>
          </div>
          <div className="stat-number">{formatNumber(statistics.with_phone)}</div>
          <div className="stat-subtitle">
            {calculatePercentage(statistics.with_phone, statistics.total)}% with phone numbers
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-header">
            <span className="stat-icon">✅</span>
            <span className="stat-title">Self-Referral Eligible</span>
          </div>
          <div className="stat-number">{formatNumber(statistics.self_referral_eligible)}</div>
          <div className="stat-subtitle">
            {calculatePercentage(statistics.self_referral_eligible, statistics.total)}% accept egen remiss
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-header">
            <span className="stat-icon">🏠</span>
            <span className="stat-title">Address Data</span>
          </div>
          <div className="stat-number">{formatNumber(statistics.with_address)}</div>
          <div className="stat-subtitle">
            {calculatePercentage(statistics.with_address, statistics.total)}% with full addresses
          </div>
        </div>
      </div>

      <div className="provider-breakdown">
        <h4>Provider Types</h4>
        <div className="breakdown-list">
          {Object.entries(statistics.by_type || {})
            .sort(([,a], [,b]) => b - a)
            .map(([type, count]) => (
              <div key={type} className="breakdown-item">
                <div className="breakdown-label">
                  <span className="breakdown-icon">
                    {getTypeIcon(type)}
                  </span>
                  <span>{formatTypeName(type)}</span>
                </div>
                <div className="breakdown-stats">
                  <span className="breakdown-count">{formatNumber(count)}</span>
                  <span className="breakdown-percentage">
                    {calculatePercentage(count, statistics.total)}%
                  </span>
                </div>
              </div>
            ))
          }
        </div>
      </div>

      <div className="data-quality">
        <h4>Data Quality</h4>
        <div className="quality-metrics">
          <div className="quality-item">
            <span className="quality-label">Completeness Score</span>
            <div className="quality-bar">
              <div 
                className="quality-fill"
                style={{
                  width: `${calculateCompleteness(statistics)}%`,
                  backgroundColor: getQualityColor(calculateCompleteness(statistics))
                }}
              ></div>
            </div>
            <span className="quality-value">{calculateCompleteness(statistics)}%</span>
          </div>
        </div>
      </div>
    </div>
  )
}

function getTypeIcon(type) {
  const icons = {
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
  return icons[type] || '🏥'
}

function formatTypeName(type) {
  const names = {
    primary_care: 'Primary Care',
    specialist: 'Specialists',
    hospital: 'Hospitals',
    dental: 'Dental Care',
    emergency: 'Emergency Services',
    mental_health: 'Mental Health',
    pediatric: 'Pediatric Care',
    maternity: 'Maternity Care',
    other: 'Other Services'
  }
  return names[type] || type.replace('_', ' ')
}

function calculateCompleteness(stats) {
  const total = stats.total || 1
  const coordinates = (stats.with_coordinates || 0) / total * 25
  const phone = (stats.with_phone || 0) / total * 25
  const address = (stats.with_address || 0) / total * 25
  const baseline = 25 // Base score for having provider names and IDs
  
  return Math.round(coordinates + phone + address + baseline)
}

function getQualityColor(percentage) {
  if (percentage >= 90) return '#10b981'
  if (percentage >= 75) return '#f59e0b'
  if (percentage >= 60) return '#ef4444'
  return '#6b7280'
}