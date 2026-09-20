variable "project_id" {
  type = string
}
variable "region" {
  type = string
}
variable "bucket_name" {
  type = string
}
variable "enable_versioning" {
  type    = bool
  default = true
}
variable "retention_days" {
  type    = number
  default = null
}
variable "force_destroy" {
  type    = bool
  default = false
}
variable "labels" {
  type    = map(string)
  default = {}
}