"use client"

import { toast as sonnerToast } from "sonner"

export type ToastOptions = {
  title: string
  description?: string
  variant?: "default" | "destructive"
}

export function useToast() {
  return {
    toast: ({ title, description, variant = "default" }: ToastOptions) => {
      const options = description ? { description } : {}
      if (variant === "destructive") {
        sonnerToast.error(title, options)
      } else {
        sonnerToast.success(title, options)
      }
    },
  }
}
