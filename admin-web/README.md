# Admin Web App

Next.js + Tailwind CSS + shadcn/ui admin interface for S3 file uploads and document processing.

## Features

- 🎨 **Modern UI** - Built with Tailwind CSS and shadcn/ui components
- 📤 **File Upload** - Upload files directly to S3 bucket
- 📄 **JSON Upload** - Special handling for JSON files with validation
- 🏥 **Health Monitoring** - Check API and S3 bucket health status
- 📱 **Responsive Design** - Works on desktop and mobile devices
- 🚀 **Static Export** - Configured for S3 static website hosting

## Tech Stack

- **Next.js 14** - React framework with App Router
- **TypeScript** - Type-safe development
- **Tailwind CSS** - Utility-first CSS framework
- **shadcn/ui** - High-quality React components
- **Radix UI** - Accessible component primitives

## Getting Started

### Prerequisites

- Node.js 18+ and npm/yarn/pnpm
- LocalStack running (for local development)
- Terraform outputs (API Gateway ID)

### Installation

```bash
# Install dependencies
npm install

# Copy environment variables
cp .env.example .env.local

# Update .env.local with your API Gateway ID
# Get it from: cd ../iac && terraform output api_gateway_id
```

### Development

```bash
# Start development server
npm run dev

# Open http://localhost:3000
```

### Build for Production

```bash
# Build static export
npm run build

# Output will be in the 'out' directory
```

## Configuration

### Environment Variables

Create `.env.local` file:

```env
NEXT_PUBLIC_API_GATEWAY_ID=your-api-gateway-id
NEXT_PUBLIC_API_STAGE=dev
NEXT_PUBLIC_API_URL=http://localhost:4566/restapis
```

### For AWS Deployment

```env
NEXT_PUBLIC_API_GATEWAY_ID=your-api-gateway-id
NEXT_PUBLIC_API_STAGE=prod
NEXT_PUBLIC_API_URL=https://your-api-id.execute-api.us-east-1.amazonaws.com
```

## Deployment to S3

### Build Static Export

```bash
npm run build
```

This creates an `out/` directory with static files.

### Deploy to S3

```bash
# Using AWS CLI
aws s3 sync out/ s3://your-bucket-name --delete

# Or use the Makefile command
make deploy-admin-web
```

### Enable Static Website Hosting

```bash
aws s3 website s3://your-bucket-name \
  --index-document index.html \
  --error-document 404.html
```

## Project Structure

```
admin-web/
├── app/                    # Next.js App Router
│   ├── layout.tsx        # Root layout
│   ├── page.tsx          # Home page
│   └── globals.css       # Global styles
├── components/            # React components
│   ├── ui/               # shadcn/ui components
│   ├── file-upload.tsx   # File upload component
│   └── health-status.tsx # Health check component
├── lib/                   # Utilities
│   ├── api.ts            # API client
│   └── utils.ts          # Helper functions
└── public/               # Static assets
```

## Features

### File Upload

- Upload any file type to S3
- Optional folder organization
- Real-time upload progress
- Error handling and validation

### JSON Upload

- Special JSON file handling
- Format validation
- Preview of JSON structure

### Health Monitoring

- API health checks
- S3 bucket accessibility
- Real-time status updates

## Development

### Adding New Components

```bash
# Add shadcn/ui component
npx shadcn-ui@latest add [component-name]
```

### Styling

- Uses Tailwind CSS utility classes
- Custom theme in `tailwind.config.ts`
- CSS variables for theming

## Troubleshooting

### CORS Issues

If you encounter CORS errors, ensure:
1. API Gateway has CORS enabled
2. FastAPI Lambda has CORS middleware configured
3. S3 bucket CORS policy allows your domain

### API Connection Issues

- Verify API Gateway ID is correct
- Check LocalStack is running (for local dev)
- Verify API Gateway stage name matches

### Build Issues

- Ensure `output: 'export'` in `next.config.js`
- Check all images use `unoptimized: true`
- Verify no server-side features are used
