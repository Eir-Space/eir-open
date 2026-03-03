#!/usr/bin/env node

import fs from 'fs/promises'
import path from 'path'
import { extractProviderInsights } from '../lib/provider-description.js'

const DEFAULT_INPUT = 'public/data/providers-sweden.json'
const DEFAULT_OUTPUT = 'public/data/providers-sweden-verified.json'
const DEFAULT_CONCURRENCY = 4
const DEFAULT_TIMEOUT_MS = 15000
const DEFAULT_DELAY_MS = 200
const DEFAULT_MODE = 'strict'
const DEFAULT_RETRIES = 2

async function main() {
  const options = parseArgs(process.argv.slice(2))
  const inputPath = path.resolve(process.cwd(), options.input || DEFAULT_INPUT)
  const outputPath = path.resolve(process.cwd(), options.output || DEFAULT_OUTPUT)

  const raw = await fs.readFile(inputPath, 'utf8')
  const dataset = JSON.parse(raw)
  const providers = Array.isArray(dataset.providers) ? dataset.providers : []

  const targets = providers
    .filter(provider => is1177Url(provider?.contact?.website))
    .filter(provider => !options.onlySelfReferral || Boolean(provider?.services?.self_referral))
    .filter(provider => !options.onlyUnresolved || provider?.services?.self_referral_verification_status === 'unresolved')
    .slice(0, options.limit || providers.length)

  if (targets.length === 0) {
    console.log('No matching 1177 providers to verify.')
    return
  }

  console.log(`Verifying self-referral on ${targets.length} providers...`)
  const start = Date.now()
  const tasks = targets.map(provider => async () => verifyProvider(provider, options))
  const results = await runWithConcurrency(tasks, options.concurrency || DEFAULT_CONCURRENCY)
  const resultById = new Map(results.map(item => [item.id, item]))

  let verifiedTrue = 0
  let verifiedFalse = 0
  let unresolved = 0

  const updatedProviders = providers.map(provider => {
    const result = resultById.get(provider.id)
    if (!result) return provider

    const services = { ...(provider.services || {}) }
    const metadata = { ...(provider.metadata || {}) }

    if (typeof result.verified === 'boolean') {
      services.self_referral_verified = result.verified
      services.self_referral_verification_status = 'verified'
      if (options.mode === 'strict') {
        services.self_referral = result.verified
      } else if (options.mode === 'additive') {
        services.self_referral = Boolean(services.self_referral || result.verified)
      }
      if (result.verified) {
        verifiedTrue += 1
      } else {
        verifiedFalse += 1
      }
    } else {
      services.self_referral_verification_status = 'unresolved'
      unresolved += 1
    }

    if (Array.isArray(result.eServices)) {
      services.e_services = result.eServices
    }

    metadata.self_referral_verified_at = new Date().toISOString()
    metadata.self_referral_verification_source = '1177_live_scrape'

    return {
      ...provider,
      services,
      metadata
    }
  })

  const updated = {
    ...dataset,
    metadata: {
      ...(dataset.metadata || {}),
      data_version: bumpVersion(dataset?.metadata?.data_version),
      self_referral_verification: {
        generated: new Date().toISOString(),
        mode: options.mode,
        checked_providers: targets.length,
        verified_true: verifiedTrue,
        verified_false: verifiedFalse,
        unresolved
      }
    },
    providers: updatedProviders
  }

  await fs.writeFile(outputPath, `${JSON.stringify(updated, null, 2)}\n`, 'utf8')

  const elapsedMs = Date.now() - start
  console.log(`Wrote: ${outputPath}`)
  console.log(`Verified true: ${verifiedTrue}`)
  console.log(`Verified false: ${verifiedFalse}`)
  console.log(`Unresolved: ${unresolved}`)
  console.log(`Elapsed: ${(elapsedMs / 1000).toFixed(1)}s`)
}

async function verifyProvider(provider, options) {
  const url = provider?.contact?.website
  if (!is1177Url(url)) return { id: provider?.id, verified: null, eServices: [] }

  try {
    if (options.delayMs > 0) {
      await sleep(jitterDelay(options.delayMs))
    }
    const attempt = await fetchWithRetries(url, options)
    if (!attempt) return { id: provider.id, verified: null, eServices: [] }
    return {
      id: provider.id,
      verified: Boolean(attempt.supportsSelfReferral),
      eServices: (attempt.eServices || []).map(service => service.text).filter(Boolean)
    }
  } catch {
    return { id: provider.id, verified: null, eServices: [] }
  }
}

function fetchWithTimeout(url, timeoutMs) {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs || DEFAULT_TIMEOUT_MS)
  return fetch(url, {
    signal: controller.signal,
    headers: {
      'user-agent': 'EIR Provider Directory verifier/1.0'
    }
  }).finally(() => clearTimeout(timeoutId))
}

async function fetchWithRetries(url, options) {
  const retries = Math.max(0, Number(options.retries ?? DEFAULT_RETRIES))
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const response = await fetchWithTimeout(url, options.timeoutMs)
      if (response.ok) {
        const html = await response.text()
        return extractProviderInsights(html)
      }
    } catch {}

    if (attempt < retries) {
      const backoffMs = (options.delayMs || DEFAULT_DELAY_MS) * (attempt + 2)
      await sleep(backoffMs)
    }
  }
  return null
}

async function runWithConcurrency(taskFactories, concurrency) {
  const output = []
  const running = new Set()
  let index = 0

  async function startNext() {
    while (running.size < concurrency && index < taskFactories.length) {
      const taskIndex = index++
      const promise = taskFactories[taskIndex]().then(result => {
        output[taskIndex] = result
      })
      running.add(promise)
      promise.finally(() => running.delete(promise))
    }

    if (running.size === 0) return
    await Promise.race(running)
    await startNext()
  }

  await startNext()
  return output
}

function parseArgs(args) {
  const options = {
    input: DEFAULT_INPUT,
    output: DEFAULT_OUTPUT,
    concurrency: DEFAULT_CONCURRENCY,
    timeoutMs: DEFAULT_TIMEOUT_MS,
    delayMs: DEFAULT_DELAY_MS,
    mode: DEFAULT_MODE,
    retries: DEFAULT_RETRIES,
    limit: null,
    onlySelfReferral: true,
    onlyUnresolved: false
  }

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]
    if (arg === '--input') options.input = args[++i]
    if (arg === '--output') options.output = args[++i]
    if (arg === '--concurrency') options.concurrency = Number(args[++i]) || DEFAULT_CONCURRENCY
    if (arg === '--timeout') options.timeoutMs = Number(args[++i]) || DEFAULT_TIMEOUT_MS
    if (arg === '--delay') options.delayMs = Number(args[++i]) || DEFAULT_DELAY_MS
    if (arg === '--mode') options.mode = args[++i] === 'additive' ? 'additive' : 'strict'
    if (arg === '--retries') options.retries = Number(args[++i]) || DEFAULT_RETRIES
    if (arg === '--limit') options.limit = Number(args[++i]) || null
    if (arg === '--all') options.onlySelfReferral = false
    if (arg === '--only-unresolved') options.onlyUnresolved = true
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
  const jitter = Math.floor(Math.random() * Math.max(1, baseMs))
  return baseMs + jitter
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
  console.error('Verification script failed:', error?.message || error)
  process.exit(1)
})
