output "enabled_apis" {
  description = "Successfully enable hui APIs ki list"
  value       = [for api in google_project_service.apis : api.service]
}