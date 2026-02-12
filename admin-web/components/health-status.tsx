"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { CheckCircle2, XCircle, Loader2, RefreshCw } from "lucide-react"
import { checkHealth, ApiError } from "@/lib/api"
import { useToast } from "@/components/ui/use-toast"

export function HealthStatus() {
  const [health, setHealth] = useState<{ status: string; accessible: boolean; error?: { code: string; message: string }; bucket?: string } | null>(null)
  const [isChecking, setIsChecking] = useState(false)
  const { toast } = useToast()

  const checkApiHealth = async () => {
    setIsChecking(true)
    try {
      const result = await checkHealth()
      setHealth(result)
      
      if (result.accessible) {
        toast({
          title: "API is healthy",
          description: `S3 bucket ${result.bucket} is accessible`,
        })
      } else {
        // Health check returned unhealthy status (200 OK but accessible: false)
        const errorMsg = result.error 
          ? `${result.error.code}: ${result.error.message}`
          : "S3 bucket is not accessible"
        toast({
          title: "API health check failed",
          description: errorMsg,
          variant: "destructive",
        })
      }
    } catch (error) {
      let errorMessage = "Failed to check API health"
      let errorDetails = ""
      
      if (error instanceof ApiError) {
        errorMessage = error.message
        if (error.data) {
          errorDetails = typeof error.data === 'string' ? error.data : JSON.stringify(error.data)
        }
      } else if (error instanceof Error) {
        errorMessage = error.message
      }
      
      setHealth({ status: "error", accessible: false })
      toast({
        title: "Health check failed",
        description: errorDetails || errorMessage,
        variant: "destructive",
      })
      
      // Log to console for debugging
      console.error("Health check error:", error)
    } finally {
      setIsChecking(false)
    }
  }

  useEffect(() => {
    checkApiHealth()
  }, [])

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          {isChecking ? (
            <Loader2 className="h-5 w-5 animate-spin" />
          ) : health?.accessible ? (
            <CheckCircle2 className="h-5 w-5 text-green-500" />
          ) : (
            <XCircle className="h-5 w-5 text-red-500" />
          )}
          API Health Status
        </CardTitle>
        <CardDescription>
          Check the connection status to the FastAPI Lambda and S3 bucket
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {health && (
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">Status:</span>
              <span className={`text-sm font-semibold ${
                health.accessible ? "text-green-600" : "text-red-600"
              }`}>
                {health.accessible ? "Healthy" : "Unhealthy"}
              </span>
            </div>
            {health.bucket && (
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">Bucket:</span>
                <span className="text-sm text-muted-foreground">{health.bucket}</span>
              </div>
            )}
            {health.error && (
              <div className="mt-2 p-2 bg-red-50 dark:bg-red-950 rounded-md">
                <div className="text-xs font-medium text-red-800 dark:text-red-200">
                  Error: {health.error.code}
                </div>
                <div className="text-xs text-red-600 dark:text-red-300 mt-1">
                  {health.error.message}
                </div>
              </div>
            )}
          </div>
        )}
        
        <Button
          onClick={checkApiHealth}
          disabled={isChecking}
          variant="outline"
          className="w-full"
        >
          {isChecking ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Checking...
            </>
          ) : (
            <>
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh Status
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  )
}
