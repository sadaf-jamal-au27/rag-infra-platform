# ─────────────────────────────────────────────
# Outputs — dusre modules ya root config ye values use kar sakte hain
# ─────────────────────────────────────────────

output "bucket_name" {
  description = "Bana hua bucket ka naam"
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "Bucket ka gs:// URL"
  value       = google_storage_bucket.this.url
}

output "bucket_self_link" {
  description = "Bucket ka full API self-link"
  value       = google_storage_bucket.this.self_link
}
