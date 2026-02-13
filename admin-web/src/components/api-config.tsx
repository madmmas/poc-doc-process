"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Info } from "lucide-react"

export function ApiConfig() {
  const apiId = process.env.NEXT_PUBLIC_API_GATEWAY_ID || "Not configured"
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || "Not configured"
  const stage = process.env.NEXT_PUBLIC_API_STAGE || "dev"
  
  // Construct the full API URL
  let fullApiUrl = "Not configured"
  if (apiId !== "Not configured" && apiUrl !== "Not configured") {
    if (apiUrl.includes('localhost') || apiUrl.includes('127.0.0.1')) {
      fullApiUrl = `${apiUrl}/${apiId}/${stage}/_user_request_`
    } else {
      fullApiUrl = `${apiUrl}/${stage}`
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Info className="h-5 w-5" />
          API Configuration
        </CardTitle>
        <CardDescription>
          Current API endpoint configuration
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">API Gateway ID:</span>
          <span className="text-sm text-muted-foreground font-mono">{apiId}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">Stage:</span>
          <span className="text-sm text-muted-foreground">{stage}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">Base URL:</span>
          <span className="text-sm text-muted-foreground font-mono text-xs break-all">{apiUrl}</span>
        </div>
        <div className="pt-2 border-t">
          <span className="text-sm font-medium">Full API URL:</span>
          <p className="text-xs text-muted-foreground font-mono break-all mt-1">{fullApiUrl}</p>
        </div>
        {apiId === "Not configured" && (
          <p className="text-xs text-yellow-600 dark:text-yellow-400 mt-2">
            ⚠️ Configure NEXT_PUBLIC_API_GATEWAY_ID in .env.local
          </p>
        )}
      </CardContent>
    </Card>
  )
}
