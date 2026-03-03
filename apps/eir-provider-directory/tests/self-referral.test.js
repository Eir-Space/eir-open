import { describe, expect, it } from 'vitest'
import {
  getSelfReferralVerificationLabel,
  getSelfReferralVerificationStatus,
  hasVerifiedSelfReferral
} from '../lib/self-referral'

describe('hasVerifiedSelfReferral', () => {
  it('prefers verified false over legacy self_referral true', () => {
    expect(
      hasVerifiedSelfReferral({
        services: { self_referral: true, self_referral_verified: false }
      })
    ).toBe(false)
  })

  it('uses verified true when present', () => {
    expect(
      hasVerifiedSelfReferral({
        services: { self_referral: false, self_referral_verified: true }
      })
    ).toBe(true)
  })

  it('falls back to legacy field when verified flag is missing', () => {
    expect(
      hasVerifiedSelfReferral({
        services: { self_referral: true }
      })
    ).toBe(true)
  })

  it('maps verification status and labels', () => {
    const unresolved = {
      services: { self_referral_verification_status: 'unresolved' }
    }
    expect(getSelfReferralVerificationStatus(unresolved)).toBe('unresolved')
    expect(getSelfReferralVerificationLabel(unresolved)).toContain('pending')

    const verifiedNo = {
      services: { self_referral_verified: false, self_referral_verification_status: 'verified' }
    }
    expect(getSelfReferralVerificationStatus(verifiedNo)).toBe('verified_no')
    expect(getSelfReferralVerificationLabel(verifiedNo)).toContain('no self-referral')
  })
})
