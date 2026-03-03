export function hasVerifiedSelfReferral(provider) {
  const services = provider?.services || {}

  if (typeof services.self_referral_verified === 'boolean') {
    return services.self_referral_verified
  }

  return Boolean(services.self_referral)
}

export function getSelfReferralVerificationStatus(provider) {
  const services = provider?.services || {}
  const explicitStatus = services.self_referral_verification_status

  if (explicitStatus === 'verified' && typeof services.self_referral_verified === 'boolean') {
    return services.self_referral_verified ? 'verified_yes' : 'verified_no'
  }

  if (typeof services.self_referral_verified === 'boolean') {
    return services.self_referral_verified ? 'verified_yes' : 'verified_no'
  }

  if (explicitStatus === 'unresolved') return 'unresolved'

  return 'unchecked'
}

export function getSelfReferralVerificationLabel(provider) {
  const status = getSelfReferralVerificationStatus(provider)
  if (status === 'verified_yes') return '1177: self-referral verified'
  if (status === 'verified_no') return '1177: no self-referral'
  if (status === 'unresolved') return '1177: verification pending'
  return '1177: not checked'
}
