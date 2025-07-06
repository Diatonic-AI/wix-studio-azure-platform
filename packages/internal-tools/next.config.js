/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  images: {
    domains: ['static.wixstatic.com'],
  },
  env: {
    CUSTOM_KEY: 'wix-studio-agency',
  },
}

module.exports = nextConfig
