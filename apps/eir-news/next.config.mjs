/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    SITE_URL: process.env.SITE_URL || 'https://news.eir.space',
  },
};

export default nextConfig;
