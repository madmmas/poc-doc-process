import { FileUpload } from "@/components/file-upload";

export default function SummerizerPage() {
  return (
    <div className="min-h-screen">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold tracking-tight mb-2">
            Upload Files to S3
          </h1>
          <p className="text-muted-foreground">
            Upload a JSON file into the S3 bucket to be processed by the summarizer
          </p>
        </div>
        <div className="grid gap-6 md:grid-cols-2">
          <FileUpload />
        </div>
      </div>
    </div>
  )
}