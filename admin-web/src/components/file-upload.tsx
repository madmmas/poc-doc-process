"use client"

import { useState, useCallback } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Upload, FileJson, Folder, Loader2 } from "lucide-react"
import { uploadJsonFile, ApiError } from "@/lib/api"
import { useToast } from "@/hooks/use-toast"

export function FileUpload() {
  const [file, setFile] = useState<File | null>(null)
  const [folder, setFolder] = useState("")
  const [isUploading, setIsUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState<string>("")
  const { toast } = useToast()

  const handleFileChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0]
    if (selectedFile) {
      setFile(selectedFile)
      setUploadProgress("")
    }
  }, [])

  const handleJsonUpload = useCallback(async () => {
    if (!file) {
      toast({
        title: "No file selected",
        description: "Please select a JSON file to upload",
        variant: "destructive",
      })
      return
    }

    // Validate JSON file
    if (!file.name.endsWith('.json')) {
      toast({
        title: "Invalid file type",
        description: "Please select a JSON file",
        variant: "destructive",
      })
      return
    }

    setIsUploading(true)
    setUploadProgress("Uploading JSON file...")

    try {
      const result = await uploadJsonFile(file)
      
      toast({
        title: "JSON upload successful",
        description: `File ${result.filename} uploaded${result.json_preview ? ` with ${result.json_preview.key_count} keys` : ''}`,
      })
      
      setUploadProgress(`Success! JSON file uploaded to ${result.key}`)
      setFile(null)
      
      // Reset file input
      const fileInput = document.getElementById("file-input") as HTMLInputElement
      if (fileInput) fileInput.value = ""
      
    } catch (error) {
      const errorMessage = error instanceof ApiError 
        ? error.data?.detail || error.message
        : "Failed to upload JSON file"
      
      toast({
        title: "Upload failed",
        description: errorMessage,
        variant: "destructive",
      })
      
      setUploadProgress(`Error: ${errorMessage}`)
    } finally {
      setIsUploading(false)
    }
  }, [file, toast])

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Upload className="h-5 w-5" />
          Upload Files to S3
        </CardTitle>
        <CardDescription>
          Upload files to the S3 bucket. Files will be placed in the "new/" folder to trigger processing.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="file-input">Select File</Label>
          <Input
            id="file-input"
            type="file"
            onChange={handleFileChange}
            disabled={isUploading}
          />
          {file && (
            <p className="text-sm text-muted-foreground">
              Selected: {file.name} ({(file.size / 1024).toFixed(2)} KB)
            </p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="folder-input">Folder (optional)</Label>
          <div className="flex items-center gap-2">
            <Folder className="h-4 w-4 text-muted-foreground" />
            <Input
              id="folder-input"
              type="text"
              placeholder="documents"
              value={folder}
              onChange={(e) => setFolder(e.target.value)}
              disabled={isUploading}
            />
          </div>
          <p className="text-xs text-muted-foreground">
            Files will be uploaded to: new/{folder ? `${folder}/` : ""}[filename]
          </p>
        </div>

        {uploadProgress && (
          <div className="p-3 bg-muted rounded-md">
            <p className="text-sm">{uploadProgress}</p>
          </div>
        )}

        <div className="flex gap-2">
          <Button
            onClick={handleJsonUpload}
            disabled={!file || isUploading || !file.name.endsWith('.json')}
            variant="secondary"
            className="flex-1"
          >
            {isUploading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Uploading...
              </>
            ) : (
              <>
                <FileJson className="mr-2 h-4 w-4" />
                Upload JSON
              </>
            )}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
