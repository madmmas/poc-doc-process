const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4566/restapis';

export interface UploadResponse {
  status: string;
  message: string;
  bucket: string;
  key: string;
  filename: string;
  size: number;
  content_type: string;
  s3_url: string;
  json_preview?: {
    keys: string[];
    key_count: number;
  };
}

export interface HealthResponse {
  status: string;
  bucket: string;
  accessible: boolean;
  error?: {
    code: string;
    message: string;
  };
  s3_endpoint?: string;
  region?: string;
}

export class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    public data?: any
  ) {
    super(`API Error: ${status} ${statusText}`);
    this.name = 'ApiError';
  }
}

/**
 * Get API Gateway URL from environment or use default
 */
function getApiUrl(): string {
  const apiId = process.env.NEXT_PUBLIC_API_GATEWAY_ID;
  const stage = process.env.NEXT_PUBLIC_API_STAGE || 'dev';
  
  if (apiId) {
    // LocalStack format: http://localhost:4566/restapis/{apiId}/{stage}/_user_request_
    // AWS format: https://{apiId}.execute-api.{region}.amazonaws.com/{stage}
    if (API_BASE_URL.includes('localhost') || API_BASE_URL.includes('127.0.0.1')) {
      return `${API_BASE_URL}/${apiId}/${stage}/_user_request_`;
    } else {
      // AWS API Gateway format
      return `${API_BASE_URL}/${stage}`;
    }
  }
  
  // Fallback for local development - try root endpoint
  console.warn('NEXT_PUBLIC_API_GATEWAY_ID not set, using fallback URL:', API_BASE_URL);
  return API_BASE_URL;
}

/**
 * Health check endpoint
 */
export async function checkHealth(): Promise<HealthResponse> {
  const apiUrl = getApiUrl();
  const healthUrl = `${apiUrl}/api/health`;  // Use /api prefix to avoid conflict with dedicated health endpoint
  
  try {
    const response = await fetch(healthUrl, {
      method: 'GET',
      mode: 'cors', // Explicitly enable CORS
      headers: {
        'Content-Type': 'application/json',
      },
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new ApiError(response.status, response.statusText, errorText);
    }
    
    return response.json();
  } catch (error) {
    // Network error or CORS issue
    if (error instanceof TypeError) {
      throw new ApiError(0, 'Network Error', `Failed to connect to ${healthUrl}. Check CORS and API URL configuration.`);
    }
    throw error;
  }
}

/**
 * Upload JSON file to S3
 */
export async function uploadJsonFile(file: File): Promise<UploadResponse> {
  const apiUrl = getApiUrl();
  const uploadUrl = `${apiUrl}/api/upload/json`;  // Use /api prefix
  
  const formData = new FormData();
  formData.append('file', file);
  
  try {
    const response = await fetch(uploadUrl, {
      method: 'POST',
      mode: 'cors', // Explicitly enable CORS
      body: formData,
    });
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new ApiError(response.status, response.statusText, errorData);
    }
  
    return response.json();
  } catch (error) {
    if (error instanceof TypeError) {
      throw new ApiError(0, 'Network Error', `Failed to connect to ${uploadUrl}. Check CORS and API URL configuration.`);
    }
    throw error;
  }
}
