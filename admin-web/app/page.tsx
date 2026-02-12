"use client"

import { FileUpload } from "@/components/file-upload"
import { HealthStatus } from "@/components/health-status"
import { ApiConfig } from "@/components/api-config"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Upload, Database, FileText } from "lucide-react"

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
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

        {/* Stats Cards */}
        <div className="grid gap-4 md:grid-cols-3 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Upload Status</CardTitle>
              <Upload className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">Ready</div>
              <p className="text-xs text-muted-foreground">
                Upload files to trigger processing
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">S3 Bucket</CardTitle>
              <Database className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">scrap-document-poc</div>
              <p className="text-xs text-muted-foreground">
                Document storage bucket
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Processing</CardTitle>
              <FileText className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">Active</div>
              <p className="text-xs text-muted-foreground">
                Lambda functions ready
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Main Content */}
        <div className="grid gap-6 md:grid-cols-2">
          <FileUpload />
          <HealthStatus />
        </div>

        {/* API Configuration (for debugging) */}
        <div className="mt-6">
          <ApiConfig />
        </div>

        {/* Info Section */}
        <Card className="mt-6">
          <CardHeader>
            <CardTitle>How It Works</CardTitle>
            <CardDescription>
              Understanding the document processing workflow
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary text-primary-foreground font-semibold">
                    1
                  </div>
                  <h3 className="font-semibold">Upload</h3>
                </div>
                <p className="text-sm text-muted-foreground ml-10">
                  Upload files to the <code className="bg-muted px-1 rounded">new/</code> folder
                </p>
              </div>
              
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary text-primary-foreground font-semibold">
                    2
                  </div>
                  <h3 className="font-semibold">Process</h3>
                </div>
                <p className="text-sm text-muted-foreground ml-10">
                  Lambda function processes the document and generates summary
                </p>
              </div>
              
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary text-primary-foreground font-semibold">
                    3
                  </div>
                  <h3 className="font-semibold">Move</h3>
                </div>
                <p className="text-sm text-muted-foreground ml-10">
                  File moved to <code className="bg-muted px-1 rounded">processed/</code> or <code className="bg-muted px-1 rounded">failed/</code>
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
