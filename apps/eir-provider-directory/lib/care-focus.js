const CARE_FOCUS_DEFINITIONS = [
  {
    id: 'primary-care',
    label: 'Primary care',
    typeMatches: ['primary_care'],
    keywords: ['vårdcentral', 'halsocentral', 'hälsocentral', 'allmanmedicin', 'allmänmedicin']
  },
  {
    id: 'mental-health',
    label: 'Mental health',
    typeMatches: ['mental_health'],
    keywords: ['psykiatri', 'psykologi', 'bup', 'depression', 'angest', 'ångest', 'ocd']
  },
  {
    id: 'women-health',
    label: 'Women health',
    typeMatches: ['maternity'],
    keywords: ['gynekologi', 'barnmorska', 'gravid', 'forlossning', 'förlossning']
  },
  {
    id: 'children',
    label: 'Children',
    typeMatches: ['pediatric'],
    keywords: ['barn', 'bvc', 'ungdom']
  },
  {
    id: 'dental',
    label: 'Dental',
    typeMatches: ['dental'],
    keywords: ['tand', 'dent']
  },
  {
    id: 'heart-circulation',
    label: 'Heart & circulation',
    keywords: ['kardiologi', 'hjart', 'hjärt', 'cardio']
  },
  {
    id: 'skin',
    label: 'Skin',
    keywords: ['dermatologi', 'hud']
  },
  {
    id: 'bones-joints',
    label: 'Bones & joints',
    keywords: ['ortopedi', 'reumatologi', 'fysioterapi', 'rehab', 'smarta', 'smärta']
  },
  {
    id: 'brain-neuro',
    label: 'Brain & neuro',
    keywords: ['neurologi', 'neuro']
  },
  {
    id: 'eyes-ent',
    label: 'Eyes, ears, nose, throat',
    keywords: ['ogon', 'ögon', 'ent', 'oron', 'öron', 'nasa', 'näsa', 'hals']
  },
  {
    id: 'digestive',
    label: 'Digestive',
    keywords: ['gastro', 'mage', 'tarm']
  },
  {
    id: 'urology-kidney',
    label: 'Urology & kidney',
    keywords: ['urologi', 'njur', 'urin']
  },
  {
    id: 'cancer',
    label: 'Cancer',
    keywords: ['onkologi', 'cancer', 'tumor']
  },
  {
    id: 'imaging-lab',
    label: 'Imaging & lab',
    keywords: ['radiologi', 'rontgen', 'röntgen', 'patologi', 'lab']
  },
  {
    id: 'acute',
    label: 'Acute & emergency',
    typeMatches: ['emergency', 'hospital'],
    keywords: ['akut', 'ambulans', 'sjukhus', 'hospital']
  }
]

export const CARE_FOCUS_LABELS = CARE_FOCUS_DEFINITIONS.reduce((acc, definition) => {
  acc[definition.id] = definition.label
  return acc
}, {})

export function deriveProviderCareFocuses(provider) {
  const type = (provider?.type || '').toLowerCase()
  const name = (provider?.name || '').toLowerCase()
  const specialties = Array.isArray(provider?.specialty) ? provider.specialty.join(' ').toLowerCase() : ''
  const text = `${name} ${specialties}`
  const focuses = new Set()

  for (const definition of CARE_FOCUS_DEFINITIONS) {
    if (definition.typeMatches?.includes(type)) {
      focuses.add(definition.id)
      continue
    }

    if (definition.keywords?.some(keyword => text.includes(keyword))) {
      focuses.add(definition.id)
    }
  }

  if (focuses.size === 0) {
    focuses.add('general')
  }

  return Array.from(focuses)
}

export function providerHasCareFocus(provider, selectedFocuses = []) {
  if (!selectedFocuses || selectedFocuses.length === 0) return true
  const providerFocuses = deriveProviderCareFocuses(provider)
  return selectedFocuses.some(focus => providerFocuses.includes(focus))
}

export function findCareFocusesInText(query) {
  const normalized = (query || '').toLowerCase()
  if (!normalized) return []

  const matches = new Set()
  for (const definition of CARE_FOCUS_DEFINITIONS) {
    if (normalized.includes(definition.id.replace('-', ' '))) {
      matches.add(definition.id)
      continue
    }
    if (normalized.includes((definition.label || '').toLowerCase())) {
      matches.add(definition.id)
      continue
    }
    if (definition.keywords?.some(keyword => normalized.includes(keyword))) {
      matches.add(definition.id)
    }
  }
  return Array.from(matches)
}
