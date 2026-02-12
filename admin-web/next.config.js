/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export', // Enable static export for S3 deployment
  images: {
    unoptimized: true, // Required for static export
  },
  trailingSlash: true, // Better S3 compatibility
  // Disable features that require server-side rendering
  reactStrictMode: true,
}

module.exports = nextConfig
