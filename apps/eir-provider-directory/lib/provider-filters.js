import { distanceFromUser } from './distance'
import { hasVerifiedSelfReferral } from './self-referral'
import { providerHasCareFocus } from './care-focus'
import { hasMVKServices, hasVideoConsultation } from './service-capabilities'

export function filterProviders(
  providers,
  { selectedType, searchQuery, serviceFilters, careFocusFilters = [], userLocation, nearbyOnly, nearbyRadiusKm }
) {
  let filtered = providers

  if (selectedType && selectedType !== 'all') {
    filtered = filtered.filter(provider => provider.type === selectedType)
  }

  if (searchQuery) {
    const query = searchQuery.toLowerCase().trim()
    filtered = filtered.filter(provider =>
      provider.name.toLowerCase().includes(query) ||
      (provider.location?.address && provider.location.address.toLowerCase().includes(query)) ||
      (Array.isArray(provider.specialty) && provider.specialty.some(s => s.toLowerCase().includes(query))) ||
      provider.type.toLowerCase().includes(query)
    )
  }

  const servicePredicates = []
  if (serviceFilters?.selfReferral) {
    servicePredicates.push(provider => hasVerifiedSelfReferral(provider))
  }
  if (serviceFilters?.videoConsultation) {
    servicePredicates.push(provider => hasVideoConsultation(provider))
  }
  if (serviceFilters?.mvkServices) {
    servicePredicates.push(provider => hasMVKServices(provider))
  }
  if (servicePredicates.length > 0) {
    filtered = filtered.filter(provider => servicePredicates.some(predicate => predicate(provider)))
  }

  if (careFocusFilters.length > 0) {
    filtered = filtered.filter(provider => providerHasCareFocus(provider, careFocusFilters))
  }

  if (nearbyOnly && userLocation) {
    filtered = filtered.filter(provider => distanceFromUser(provider, userLocation) <= nearbyRadiusKm)
  }

  return filtered
}
