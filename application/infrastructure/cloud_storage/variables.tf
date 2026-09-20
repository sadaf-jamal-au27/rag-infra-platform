# ─────────────────────────────────────────────
# Input variables — is module ko koi bhi environment call kar sakta hai
# inhi variables ko different values dekar
# ─────────────────────────────────────────────

variable "project_id" {
  description = "GCP Project ID jahan bucket banana hai"
  type        = string
}

variable "bucket_name" {
  description = "Bucket ka globally-unique naam"
  type        = string
}

variable "location" {
  description = "Bucket ka region (jaise asia-south1)"
  type        = string
}

variable "kms_key_id" {
  description = "CMEK encryption key ka full resource ID. Null rakho to Google-managed encryption use hogi"
  type        = string
  default     = null
}

variable "enable_versioning" {
  description = "Object versioning enable karni hai (recommended: true production ke liye)"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Kitne din baad purani versions delete ho jayein. Null = kabhi delete nahi"
  type        = number
  default     = null
}

variable "force_destroy" {
  description = "true karne se terraform destroy pe bucket ke andar ki files bhi delete ho jayengi. Production me hamesha false rakho"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Compliance/cost-tracking labels (jaise environment, data-classification)"
  type        = map(string)
  default     = {}
}
variable "region" {
  description = "GCP region jahan bucket create karna hai"
  type        = string
}
