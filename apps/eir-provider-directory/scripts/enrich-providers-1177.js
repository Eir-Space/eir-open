#!/usr/bin/env node

import fs from 'fs/promises'
import fsSync from 'fs'
import path from 'path'
import { extractProviderInsights } from '../lib/provider-description.js'

const DEFAULT_INPUT = 'public/data/providers-sweden-verified.json'
const DEFAULT_FALLBACK_INPUT = 'public/data/providers-sweden.json'
const DEFAULT_OUTPUT = 'public/data/providers-sweden-verified.json'
const DEFAULT_CONCURRENCY = 3
const DEFAULT_DELAY_MS = 200
const DEFAULT_TIMEOUT_MS = 15000
const DEFAULT_RETRIES = 2
const DEFAULT_CHECKPOINT_EVERY = 50
const VIDEO_ACTION_PATTERN =
  /video|videobesok|videobesök|videomote|videomöte|video(?:\s|-)?besok|video(?:\s|-)?möte|chat/i
const MVK_ACTION_PATTERN = /\bmvk\b|mina vardkontakter|mina vårdkontakter/i

async function main() {
  const options = parseArgs(process.argv.slice(2))
  const inputPath = resolveInputPath(options.input)
  const outputPath = path.resolve(process.cwd(), options.output || DEFAULT_OUTPUT)

  const dataset = JSON.parse(await fs.readFile(inputPath, 'utf8'))
  const providers = Array.isArray(dataset.providers) ? dataset.providers : []
  const targets = buildTargets(providers, options)

  if (targets.length === 0) {
    console.log('No providers matched enrichment criteria.')
    return
  }

  console.log(`Enriching ${targets.length} providers from 1177...`)
  const startedAt = Date.now()
  const progress = {
    processed: 0,
    ok: 0,
    unresolved: 0,
    rateLimited: 0,
    networkErrors: 0
  }

  for (let i = 0; i < targets.length; i += options.concurrency) {
    const batch = targets.slice(i, i + options.concurrency)
    const results = await Promise.all(batch.map(target => enrichSingleProvider(target, options)))

    for (const result of results) {
      applyResultToProvider(providers[result.index], result)
      progress.processed += 1
      if (result.status === 'ok') progress.ok += 1
      if (result.status === 'rate_limited') progress.rateLimited += 1
      if (result.status === 'network_error') progress.networkErrors += 1
      if (result.status !== 'ok') progress.unresolved += 1
    }

    if (progress.processed % options.checkpointEvery === 0) {
      await flushCheckpoint(outputPath, dataset, progress, startedAt)
    }
  }

  await flushCheckpoint(outputPath, dataset, progress, startedAt, true)
  console.log('Enrichment completed.')
}

function resolveInputPath(inputArg) {
  if (inputArg) return path.resolve(process.cwd(), inputArg)

  const preferred = path.resolve(process.cwd(), DEFAULT_INPUT)
  if (fsSync.existsSync(preferred)) return preferred
  return path.resolve(process.cwd(), DEFAULT_FALLBACK_INPUT)
}

function buildTargets(providers, options) {
  const candidates = providers
    .map((provider, index) => ({ provider, index }))
    .filter(item => is1177Url(item.provider?.contact?.website))
    .filter(item => item.index >= options.offset)
    .filter(item => !options.onlyUnresolved || item.provider?.services?.self_referral_verification_status === 'unresolved')
    .filter(item => !options.onlyUnenriched || !item.provider?.profile_1177?.scraped_at)

  if (options.limit) return candidates.slice(0, options.limit)
  return candidates
}

async function enrichSingleProvider(target, options) {
  const provider = target.provider
  const url = provider?.contact?.website
  if (!is1177Url(url)) {
    return { index: target.index, status: 'invalid_url' }
  }

  await sleep(jitterDelay(options.delayMs))
  const fetched = await fetchWithRetries(url, options)

  if (fetched.status !== 'ok') {
    return {
      index: target.index,
      status: fetched.status,
      statusCode: fetched.statusCode || null
    }
  }

  const insights = extractProviderInsights(fetched.html)
  return {
    index: target.index,
    status: 'ok',
    snapshot: {
      description: insights.description || '',
      supportsSelfReferral: Boolean(insights.supportsSelfReferral),
      actions: Array.isArray(insights.actions) ? insights.actions : [],
      profile: insights.profile || null,
      eServices: Array.isArray(insights.eServices) ? insights.eServices : []
    }
  }
}

function applyResultToProvider(provider, result) {
  const services = { ...(provider.services || {}) }
  const metadata = { ...(provider.metadata || {}) }
  const enrichment = { ...(metadata.enrichment || {}) }
  const current = { ...(enrichment.provider_1177 || {}) }
  const nowIso = new Date().toISOString()
  const url = provider?.contact?.website || ''

  if (result.status === 'ok' && result.snapshot) {
    const snapshot = result.snapshot
    const actionNames = snapshot.actions.map(action => action.text).filter(Boolean)
    const actionTexts = snapshot.actions
      .map(action => `${action.text || ''} ${action.description_text || ''}`.trim())
      .filter(Boolean)
    const derivedVideo = actionTexts.some(text => VIDEO_ACTION_PATTERN.test(text))
    const derivedMVK = actionTexts.some(text => MVK_ACTION_PATTERN.test(text))

    services.e_services = actionNames
    services.e_services_structured = snapshot.actions
    services.self_referral_verified = snapshot.supportsSelfReferral
    services.self_referral_verification_status = 'verified'
    services.self_referral = snapshot.supportsSelfReferral
    services.video_consultation = Boolean(services.video_consultation || derivedVideo)
    services.mvk_services = Boolean(services.mvk_services || derivedMVK)

    const currentDescription = typeof provider.description === 'string' ? provider.description : ''
    if (snapshot.description && snapshot.description.length > currentDescription.length) {
      provider.description = snapshot.description
    }

    provider.profile_1177 = {
      ...(provider.profile_1177 || {}),
      ...(snapshot.profile || {}),
      description: snapshot.description,
      actions: snapshot.actions,
      action_count: snapshot.actions.length,
      source_url: url,
      scraped_at: nowIso,
      scrape_status: 'ok'
    }

    // Fill common missing fields from authoritative contact card data.
    if (snapshot.profile?.address && !provider.location?.address) {
      provider.location = provider.location || {}
      provider.location.address = snapshot.profile.address
    }
    if (snapshot.profile?.location?.latitude && snapshot.profile?.location?.longitude) {
      provider.location = provider.location || {}
      provider.location.coordinates = provider.location.coordinates || {}
      if (!provider.location.coordinates.lat) provider.location.coordinates.lat = snapshot.profile.location.latitude
      if (!provider.location.coordinates.lng) provider.location.coordinates.lng = snapshot.profile.location.longitude
    }
    if (!provider.contact?.phone && Array.isArray(snapshot.profile?.phone) && snapshot.profile.phone.length > 0) {
      const number = snapshot.profile.phone[0]?.numbers?.[0]?.national
      if (number) {
        provider.contact = provider.contact || {}
        provider.contact.phone = number
      }
    }

    enrichment.provider_1177 = {
      ...current,
      status: 'ok',
      source_url: url,
      scraped_at: nowIso,
      action_count: snapshot.actions.length
    }
  } else {
    services.self_referral_verification_status = 'unresolved'
    enrichment.provider_1177 = {
      ...current,
      status: result.status,
      source_url: url,
      scraped_at: nowIso,
      status_code: result.statusCode || null
    }
  }

  metadata.enrichment = enrichment
  provider.services = services
  provider.metadata = metadata
}

async function flushCheckpoint(outputPath, dataset, progress, startedAt, isFinal = false) {
  const now = Date.now()
  dataset.metadata = {
    ...(dataset.metadata || {}),
    data_version: bumpVersion(dataset?.metadata?.data_version),
    enrichment_1177: {
      generated: new Date().toISOString(),
      processed: progress.processed,
      ok: progress.ok,
      unresolved: progress.unresolved,
      rate_limited: progress.rateLimited,
      network_errors: progress.networkErrors,
      elapsed_seconds: Math.round((now - startedAt) / 1000),
      final: isFinal
    }
  }

  await fs.writeFile(outputPath, `${JSON.stringify(dataset, null, 2)}\n`, 'utf8')
  const stage = isFinal ? 'final' : 'checkpoint'
  console.log(
    `[${stage}] processed=${progress.processed} ok=${progress.ok} unresolved=${progress.unresolved} rate_limited=${progress.rateLimited}`
  )
}

async function fetchWithRetries(url, options) {
  for (let attempt = 0; attempt <= options.retries; attempt += 1) {
    try {
      const response = await fetchWithTimeout(url, options.timeoutMs)
      if (response.status === 429 || response.status === 403) {
        return { status: 'rate_limited', statusCode: response.status }
      }
      if (!response.ok) {
        return { status: 'http_error', statusCode: response.status }
      }
      const html = await response.text()
      return { status: 'ok', html }
    } catch {
      if (attempt === options.retries) {
        return { status: 'network_error' }
      }
      await sleep(options.delayMs * (attempt + 2))
    }
  }

  return { status: 'network_error' }
}

function fetchWithTimeout(url, timeoutMs) {
  const controller = new AbortController()
  const timerId = setTimeout(() => controller.abort(), timeoutMs)
  return fetch(url, {
    signal: controller.signal,
    headers: {
      'user-agent': 'EIR Provider Directory enrichment/1.0'
    }
  }).finally(() => clearTimeout(timerId))
}

function parseArgs(args) {
  const options = {
    input: '',
    output: DEFAULT_OUTPUT,
    concurrency: DEFAULT_CONCURRENCY,
    delayMs: DEFAULT_DELAY_MS,
    timeoutMs: DEFAULT_TIMEOUT_MS,
    retries: DEFAULT_RETRIES,
    offset: 0,
    limit: 0,
    checkpointEvery: DEFAULT_CHECKPOINT_EVERY,
    onlyUnresolved: false,
    onlyUnenriched: false
  }

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]
    if (arg === '--input') options.input = args[++i] || ''
    if (arg === '--output') options.output = args[++i] || DEFAULT_OUTPUT
    if (arg === '--concurrency') options.concurrency = Number(args[++i]) || DEFAULT_CONCURRENCY
    if (arg === '--delay') options.delayMs = Number(args[++i]) || DEFAULT_DELAY_MS
    if (arg === '--timeout') options.timeoutMs = Number(args[++i]) || DEFAULT_TIMEOUT_MS
    if (arg === '--retries') options.retries = Number(args[++i]) || DEFAULT_RETRIES
    if (arg === '--offset') options.offset = Number(args[++i]) || 0
    if (arg === '--limit') options.limit = Number(args[++i]) || 0
    if (arg === '--checkpoint-every') {
      options.checkpointEvery = Number(args[++i]) || DEFAULT_CHECKPOINT_EVERY
    }
    if (arg === '--only-unresolved') options.onlyUnresolved = true
    if (arg === '--only-unenriched') options.onlyUnenriched = true
  }

  return options
}

function is1177Url(url) {
  try {
    const parsed = new URL(url)
    return parsed.hostname.includes('1177.se')
  } catch {
    return false
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

function jitterDelay(baseMs) {
  return baseMs + Math.floor(Math.random() * Math.max(1, baseMs))
}

function bumpVersion(version) {
  if (typeof version !== 'string') return '1.1'
  const [majorRaw, minorRaw] = version.split('.')
  const major = Number(majorRaw)
  const minor = Number(minorRaw)
  if (Number.isNaN(major) || Number.isNaN(minor)) return '1.1'
  return `${major}.${minor + 1}`
}

main().catch(error => {
  console.error('Enrichment failed:', error?.message || error)
  process.exit(1)
})
