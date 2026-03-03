import { useEffect, useMemo, useRef, useState } from 'react'
import { hasVerifiedSelfReferral } from '../lib/self-referral'

const SWEDEN_CENTER = [16, 62]
const SWEDEN_BOUNDS = [
  [10.5, 55.0],
  [24.5, 69.5]
]

export default function ProviderMap({ providers, onProviderSelect, selectedProvider, userLocation, locationFocusSeq = 0 }) {
  const mapContainerRef = useRef(null)
  const mapRef = useRef(null)
  const mapLibRef = useRef(null)
  const onProviderSelectRef = useRef(onProviderSelect)
  const userMarkerRef = useRef(null)
  const providerIndexRef = useRef(new Map())
  const [mapReady, setMapReady] = useState(false)

  useEffect(() => {
    onProviderSelectRef.current = onProviderSelect
  }, [onProviderSelect])

  const geojson = useMemo(() => {
    const features = []
    const providerIndex = new Map()

    for (const provider of providers) {
      const lat = provider.location?.coordinates?.lat
      const lng = provider.location?.coordinates?.lng
      if (!lat || !lng) continue

      providerIndex.set(provider.id, provider)
      features.push({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [lng, lat]
        },
        properties: {
          id: provider.id,
          name: provider.name,
          type: provider.type,
          self_referral: hasVerifiedSelfReferral(provider) ? 1 : 0
        }
      })
    }

    providerIndexRef.current = providerIndex
    return {
      type: 'FeatureCollection',
      features
    }
  }, [providers])

  useEffect(() => {
    let disposed = false

    async function initMap() {
      if (!mapContainerRef.current || mapRef.current) return
      const maplibregl = (await import('maplibre-gl')).default
      if (disposed) return
      mapLibRef.current = maplibregl

      const map = new maplibregl.Map({
        container: mapContainerRef.current,
        style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
        center: SWEDEN_CENTER,
        zoom: 4.6,
        minZoom: 3
      })

      map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), 'top-right')
      map.on('load', () => {
        if (disposed) return
        map.addSource('providers', {
          type: 'geojson',
          data: geojson,
          cluster: true,
          // Show individual providers earlier at broader zoom levels.
          clusterMaxZoom: 9,
          clusterRadius: 22
        })

        map.addLayer({
          id: 'clusters',
          type: 'circle',
          source: 'providers',
          filter: ['has', 'point_count'],
          paint: {
            'circle-color': ['step', ['get', 'point_count'], '#0ea5e9', 50, '#0284c7', 200, '#075985'],
            'circle-radius': ['step', ['get', 'point_count'], 16, 50, 20, 200, 24],
            'circle-stroke-width': 2,
            'circle-stroke-color': '#ffffff'
          }
        })

        map.addLayer({
          id: 'cluster-count',
          type: 'symbol',
          source: 'providers',
          filter: ['has', 'point_count'],
          layout: {
            'text-field': '{point_count_abbreviated}',
            'text-font': ['Noto Sans Regular'],
            'text-size': 12
          },
          paint: {
            'text-color': '#ffffff'
          }
        })

        map.addLayer({
          id: 'unclustered-point',
          type: 'circle',
          source: 'providers',
          filter: ['!', ['has', 'point_count']],
          paint: {
            'circle-color': [
              'match',
              ['get', 'type'],
              'hospital',
              '#ef4444',
              'specialist',
              '#2563eb',
              'primary_care',
              '#16a34a',
              'dental',
              '#d97706',
              '#4b5563'
            ],
            'circle-radius': ['case', ['==', ['get', 'self_referral'], 1], 6, 4],
            'circle-stroke-width': 1.5,
            'circle-stroke-color': '#ffffff'
          }
        })

        map.addLayer({
          id: 'selected-provider',
          type: 'circle',
          source: 'providers',
          filter: ['==', ['get', 'id'], ''],
          paint: {
            'circle-radius': 10,
            'circle-color': '#ffffff',
            'circle-stroke-width': 3,
            'circle-stroke-color': '#111827'
          }
        })

        map.on('click', 'clusters', e => {
          const feature = e.features?.[0]
          if (!feature) return
          const clusterId = feature.properties?.cluster_id
          const source = map.getSource('providers')
          source.getClusterExpansionZoom(clusterId, (err, zoom) => {
            if (err) return
            const currentZoom = map.getZoom()
            // If expansion is effectively capped, surface an actual provider from the cluster.
            if (zoom <= currentZoom + 0.2) {
              source.getClusterLeaves(clusterId, 1, 0, (leafErr, leaves) => {
                if (leafErr || !leaves?.length) return
                const providerId = leaves[0].properties?.id
                const provider = providerIndexRef.current.get(providerId)
                if (provider) onProviderSelectRef.current?.(provider)
              })
              return
            }
            map.easeTo({
              center: feature.geometry.coordinates,
              zoom: Math.max(currentZoom, zoom)
            })
          })
        })

        map.on('click', 'unclustered-point', e => {
          const feature = e.features?.[0]
          if (!feature) return
          const providerId = feature.properties?.id
          const provider = providerIndexRef.current.get(providerId)
          if (provider) onProviderSelectRef.current?.(provider)
        })

        map.on('mouseenter', 'clusters', () => {
          map.getCanvas().style.cursor = 'pointer'
        })
        map.on('mouseleave', 'clusters', () => {
          map.getCanvas().style.cursor = ''
        })
        map.on('mouseenter', 'unclustered-point', () => {
          map.getCanvas().style.cursor = 'pointer'
        })
        map.on('mouseleave', 'unclustered-point', () => {
          map.getCanvas().style.cursor = ''
        })

        map.fitBounds(SWEDEN_BOUNDS, { padding: 36, duration: 0 })
        setMapReady(true)
      })

      mapRef.current = map
    }

    initMap()

    return () => {
      disposed = true
      if (userMarkerRef.current) {
        userMarkerRef.current.remove()
        userMarkerRef.current = null
      }
      if (mapRef.current) {
        mapRef.current.remove()
        mapRef.current = null
      }
    }
  }, [])

  useEffect(() => {
    const map = mapRef.current
    if (!mapReady || !map) return
    const source = map.getSource('providers')
    if (source) source.setData(geojson)
  }, [geojson, mapReady])

  useEffect(() => {
    const map = mapRef.current
    if (!mapReady || !map) return
    const selectedId = selectedProvider?.id || ''
    if (map.getLayer('selected-provider')) {
      map.setFilter('selected-provider', ['==', ['get', 'id'], selectedId])
    }
    if (selectedProvider?.location?.coordinates?.lat && selectedProvider?.location?.coordinates?.lng) {
      map.easeTo({
        center: [selectedProvider.location.coordinates.lng, selectedProvider.location.coordinates.lat],
        duration: 600
      })
    }
  }, [selectedProvider, mapReady])

  useEffect(() => {
    const map = mapRef.current
    const maplibregl = mapLibRef.current
    if (!mapReady || !map || !maplibregl) return

    if (userMarkerRef.current) {
      userMarkerRef.current.remove()
      userMarkerRef.current = null
    }

    if (!userLocation) return

    const markerEl = document.createElement('div')
    markerEl.className = 'user-compass-marker'
    markerEl.innerHTML = '<span class="user-compass-marker__north">N</span>'

    userMarkerRef.current = new maplibregl.Marker({
      element: markerEl,
      anchor: 'center'
    })
      .setLngLat([userLocation.lng, userLocation.lat])
      .addTo(map)
  }, [userLocation, mapReady])

  useEffect(() => {
    const map = mapRef.current
    if (!mapReady || !map || !userLocation) return
    const currentZoom = map.getZoom()
    map.easeTo({
      center: [userLocation.lng, userLocation.lat],
      zoom: Math.max(currentZoom, 12),
      duration: 700
    })
  }, [locationFocusSeq, mapReady, userLocation])

  const mappedCount = geojson.features.length

  return (
    <section className="map-shell">
      <div className="map-shell-header">
        <p>
          Showing <strong>{providers.length.toLocaleString()}</strong> providers
          <span className="muted"> · {mappedCount.toLocaleString()} with map coordinates</span>
        </p>
      </div>
      <div ref={mapContainerRef} className="provider-map-canvas" />
    </section>
  )
}
