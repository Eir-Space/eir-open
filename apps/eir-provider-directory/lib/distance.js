export function toRad(value) {
  return value * (Math.PI / 180)
}

export function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2)
  return R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)))
}

export function distanceFromUser(provider, userLocation) {
  const lat = provider?.location?.coordinates?.lat
  const lng = provider?.location?.coordinates?.lng
  if (!userLocation || !lat || !lng) return Number.POSITIVE_INFINITY
  return haversineKm(userLocation.lat, userLocation.lng, lat, lng)
}
