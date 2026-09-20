resource "google_storage_bucket" "this" {
  name     = var.bucket_name
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  force_destroy = var.force_destroy

  labels = merge(var.labels, {
    managed_by = "terraform"
  })

  versioning {
    enabled = var.enable_versioning
  }

  dynamic "lifecycle_rule" {
    for_each = var.retention_days != null ? [1] : []
    content {
      condition {
        age = var.retention_days
      }
      action {
        type = "Delete"
      }
    }
  }
}