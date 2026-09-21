# project_id YAHAN NAHI hai — TF_VAR_project_id environment variable se aayega

region = "asia-south1"

apis_to_enable = [
  "aiplatform.googleapis.com",       # Vertex AI / Gemini
  "run.googleapis.com",              # Cloud Run
  "cloudfunctions.googleapis.com",   # Cloud Functions
  "firestore.googleapis.com",        # Firestore database
  "storage.googleapis.com",          # Cloud Storage
  "artifactregistry.googleapis.com", # Docker image registry
  "cloudbuild.googleapis.com",       # Container build
  "iamcredentials.googleapis.com",   # Workload Identity Federation
  "cloudresourcemanager.googleapis.com"  # Cloud Resource Manager
]