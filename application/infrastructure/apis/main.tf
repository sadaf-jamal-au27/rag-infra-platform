# ─────────────────────────────────────────────
# Zaroori GCP APIs enable karna is project ke liye
# ─────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset(var.apis_to_enable)

  project = var.project_id
  service = each.value

  disable_on_destroy         = false # destroy pe APIs disable mat karo, dusri resources break ho sakti hain
  disable_dependent_services = false
}