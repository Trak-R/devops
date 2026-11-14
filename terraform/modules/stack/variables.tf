variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "extra_tags" {
  description = "Additional tags merged onto the standard set."
  type        = map(string)
  default     = {}
}
