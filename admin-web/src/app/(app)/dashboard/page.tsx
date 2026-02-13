import { ApiConfig } from "@/components/api-config"
import { HealthStatus } from "@/components/health-status"

export default function DashboardPage() {
  return (
    <div className="min-h-screen">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold tracking-tight mb-2">
            S3 Upload Admin Dashboard
          </h1>
          <p className="text-muted-foreground">
            Manage file uploads and monitor document processing pipeline
          </p>
        </div>
        <div className="grid gap-6 md:grid-cols-2">
          {/* <FileUpload /> */}
          <ApiConfig />
          <HealthStatus />
        </div>

      </div>
    </div>
  )
}