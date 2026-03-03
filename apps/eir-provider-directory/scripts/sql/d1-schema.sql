PRAGMA foreign_keys = OFF;

CREATE TABLE IF NOT EXISTS providers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  specialty_json TEXT NOT NULL DEFAULT '[]',
  specialty_text TEXT NOT NULL DEFAULT '',
  address TEXT,
  lat REAL,
  lng REAL,
  phone TEXT,
  international_phone TEXT,
  email TEXT,
  website TEXT,
  services_json TEXT NOT NULL DEFAULT '{}',
  self_referral INTEGER NOT NULL DEFAULT 0,
  self_referral_verified INTEGER NOT NULL DEFAULT 0,
  self_referral_verification_status TEXT NOT NULL DEFAULT 'unchecked',
  video_consultation INTEGER NOT NULL DEFAULT 0,
  mvk_services INTEGER NOT NULL DEFAULT 0,
  has_listing INTEGER NOT NULL DEFAULT 0,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  description TEXT,
  updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_providers_name ON providers(name);
CREATE INDEX IF NOT EXISTS idx_providers_type ON providers(type);
CREATE INDEX IF NOT EXISTS idx_providers_address ON providers(address);
CREATE INDEX IF NOT EXISTS idx_providers_specialty_text ON providers(specialty_text);
CREATE INDEX IF NOT EXISTS idx_providers_self_referral_verified ON providers(self_referral_verified);
CREATE INDEX IF NOT EXISTS idx_providers_video_consultation ON providers(video_consultation);
CREATE INDEX IF NOT EXISTS idx_providers_mvk_services ON providers(mvk_services);
CREATE INDEX IF NOT EXISTS idx_providers_lat_lng ON providers(lat, lng);
