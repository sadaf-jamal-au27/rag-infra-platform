variable "project_id" {
  description = "GCP Project ID — TF_VAR_project_id environment variable se aata hai (secret), .tfvars me nahi"
  type        = string
}

variable "region" {
  description = "Default region (provider config ke liye chahiye)"
  type        = string
}

variable "apis_to_enable" {
  description = "Enable karne wali APIs ki list"
  type        = list(string)
}