import fs from 'fs'
import os from 'os'
import path from 'path'
import { execFileSync } from 'child_process'

const args = process.argv.slice(2)
const options = {
  source: path.join(process.cwd(), 'public/data/providers-sweden-verified.json'),
  db: 'eir-provider-db',
  remote: true,
  batchSize: 200,
  keepTemp: false
}

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i]
  if (arg === '--source' && args[i + 1]) {
    options.source = path.resolve(process.cwd(), args[i + 1])
    i += 1
  } else if (arg === '--db' && args[i + 1]) {
    options.db = args[i + 1]
    i += 1
  } else if (arg === '--local') {
    options.remote = false
  } else if (arg === '--remote') {
    options.remote = true
  } else if (arg === '--batch-size' && args[i + 1]) {
    const parsed = Number(args[i + 1])
    if (Number.isFinite(parsed) && parsed > 0) {
      options.batchSize = parsed
    }
    i += 1
  } else if (arg === '--keep-temp') {
    options.keepTemp = true
  }
}

function sqlValue(value) {
  if (value === null || value === undefined) return 'NULL'
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return 'NULL'
    return String(value)
  }
  if (typeof value === 'boolean') {
    return value ? '1' : '0'
  }
  const text = String(value).replace(/'/g, "''")
  return `'${text}'`
}

function compactServices(services = {}) {
  return {
    self_referral: Boolean(services.self_referral),
    self_referral_verified: Boolean(services.self_referral_verified),
    self_referral_verification_status: services.self_referral_verification_status || 'unchecked',
    video_consultation: Boolean(services.video_consultation),
    mvk_services: Boolean(services.mvk_services),
    has_listing: Boolean(services.has_listing),
    e_services: Array.isArray(services.e_services) ? services.e_services.slice(0, 12) : []
  }
}

function compactMetadata(metadata = {}) {
  return {
    source: metadata.source || null,
    updated: metadata.updated || null,
    country: metadata.country || null,
    eigen_remiss_research: Boolean(metadata.eigen_remiss_research)
  }
}

function rowFromProvider(provider) {
  const specialty = Array.isArray(provider.specialty) ? provider.specialty : []
  const specialtyText = specialty
    .filter(item => typeof item === 'string')
    .join(' ')
    .toLowerCase()

  const services = compactServices(provider.services || {})
  const metadata = compactMetadata(provider.metadata || {})

  return [
    provider.id,
    provider.name,
    provider.type,
    JSON.stringify(specialty),
    specialtyText,
    provider.location?.address || null,
    provider.location?.coordinates?.lat ?? null,
    provider.location?.coordinates?.lng ?? null,
    provider.contact?.phone || null,
    provider.contact?.internationalPhone || null,
    provider.contact?.email || null,
    provider.contact?.website || null,
    JSON.stringify(services),
    services.self_referral ? 1 : 0,
    services.self_referral_verified ? 1 : 0,
    services.self_referral_verification_status || 'unchecked',
    services.video_consultation ? 1 : 0,
    services.mvk_services ? 1 : 0,
    services.has_listing ? 1 : 0,
    JSON.stringify(metadata),
    provider.description || null,
    metadata.updated || null
  ]
}

function buildInsertStatement(rows) {
  const columns = [
    'id',
    'name',
    'type',
    'specialty_json',
    'specialty_text',
    'address',
    'lat',
    'lng',
    'phone',
    'international_phone',
    'email',
    'website',
    'services_json',
    'self_referral',
    'self_referral_verified',
    'self_referral_verification_status',
    'video_consultation',
    'mvk_services',
    'has_listing',
    'metadata_json',
    'description',
    'updated_at'
  ]

  const values = rows
    .map(row => `(${row.map(sqlValue).join(', ')})`)
    .join(',\n')

  return `INSERT OR REPLACE INTO providers (${columns.join(', ')}) VALUES\n${values};\n`
}

function loadProviders(sourcePath) {
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Dataset file not found: ${sourcePath}`)
  }

  const raw = fs.readFileSync(sourcePath, 'utf8')
  const data = JSON.parse(raw)
  const providers = Array.isArray(data.providers) ? data.providers : []
  if (!providers.length) {
    throw new Error('No providers found in dataset')
  }

  return providers
}

async function writeSqlFile(providers, filePath, batchSize) {
  const stream = fs.createWriteStream(filePath)
  const write = chunk => {
    if (!stream.write(chunk)) {
      return new Promise(resolve => stream.once('drain', resolve))
    }
    return Promise.resolve()
  }

  await write('DELETE FROM providers;\n')

  for (let i = 0; i < providers.length; i += batchSize) {
    const batch = providers.slice(i, i + batchSize).map(rowFromProvider)
    await write(buildInsertStatement(batch))
    const processed = Math.min(i + batchSize, providers.length)
    if (processed % (batchSize * 200) === 0 || processed === providers.length) {
      console.log(`Prepared ${processed}/${providers.length} rows...`)
    }
  }

  await new Promise(resolve => stream.end(resolve))
}

function executeImport(db, filePath, remote) {
  const command = ['wrangler', 'd1', 'execute', db, '--file', filePath]
  if (remote) {
    command.push('--remote')
  }

  execFileSync('npx', command, {
    cwd: process.cwd(),
    stdio: 'inherit'
  })
}

async function main() {
  console.log(`Reading dataset: ${options.source}`)
  const providers = loadProviders(options.source)
  console.log(`Loaded ${providers.length} providers.`)

  const tempFile = path.join(os.tmpdir(), `eir-provider-import-${Date.now()}.sql`)
  console.log(`Generating SQL import file: ${tempFile}`)
  await writeSqlFile(providers, tempFile, options.batchSize)

  console.log(`Executing D1 import into database: ${options.db} (${options.remote ? 'remote' : 'local'})`)
  executeImport(options.db, tempFile, options.remote)

  if (!options.keepTemp) {
    fs.unlinkSync(tempFile)
  } else {
    console.log(`Temp SQL kept at: ${tempFile}`)
  }

  console.log('D1 provider import completed.')
}

main().catch(error => {
  console.error('D1 import failed:', error)
  process.exit(1)
})
