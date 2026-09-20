# ─────────────────────────────────────────────
# Cloud Storage Bucket — reusable module
# CMEK encryption, versioning, aur lifecycle policy ke saath
# ─────────────────────────────────────────────

resource "google_storage_bucket" "this" {
  name     = var.bucket_name
  project  = var.project_id
  location = var.location

  # Security: bucket-level ACLs disable, sirf IAM se access control
  uniform_bucket_level_access = true

  # Accidental delete se bachao — production-grade safety
  force_destroy = var.force_destroy

  # Compliance labels — cost tracking aur data classification ke liye
  labels = merge(var.labels, {
    managed_by = "terraform"
  })

  # CMEK encryption — agar KMS key diya gaya hai to use karo,
  # warna Google-managed encryption default rahega
  dynamic "encryption" {
    for_each = var.kms_key_id != null ? [1] : []
    content {
      default_kms_key_name = var.kms_key_id
    }
  }

  # Versioning — accidental overwrite/delete se recovery (audit requirement)
  versioning {
    enabled = var.enable_versioning
  }

  # Lifecycle rule — purani non-current versions ek waqt ke baad delete
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
