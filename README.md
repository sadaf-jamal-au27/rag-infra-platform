# rag-infra-platforms
# rag-infra-platform
# RAG Agent Infrastructure — GCP + Terraform + GitHub Actions

Ye project ek hands-on learning setup hai jisme GCP par AI infrastructure (Vertex AI/Gemini-based RAG agent) banayi ja rahi hai, poori tarah Terraform se manage aur GitHub Actions se deploy ki jaati hai — banking/healthcare-grade security practices ke saath.

---

## 1. Project Overview

**Goal:** GCP free tier par ek RAG (Retrieval Augmented Generation) agent banana — jisme PDFs se text nikal ke, embeddings banake, Gemini API se sawal-jawab kiya jaaye. Poora infra Terraform se, poora deployment CI/CD se.

**Repos:**
- `rag-infra-platform` — Terraform infra + GitHub Actions (ye repo)
- App code (RAG agent — ingestion, embeddings, LangGraph agent) — abhi tak nahi shuru hua

---

## 2. GCP Project Setup

1. GCP Console pe naya project banaya: `ai-rag-agent-project`
2. $300 free trial activate kiya
3. Billing budget alert set kiya ($10, "Alerts only" mode)
4. Zaroori APIs enable kiye: `aiplatform`, `run`, `cloudfunctions`, `firestore`, `storage`, `artifactregistry`, `cloudbuild`, `iamcredentials`
5. `gcloud` CLI install kiya (Mac: `brew install --cask google-cloud-sdk`), `gcloud init` se authenticate kiya
6. Python version mismatch fix kiya (`gcloud` ko Python 3.10+ chahiye tha, `CLOUDSDK_PYTHON` env var set kiya)

### Gemini API Test
- `google-cloud-aiplatform` Python package install kiya
- `test_gemini.py` script se Gemini model (`gemini-2.5-flash` — `gemini-1.5-flash-002` deprecated ho chuka tha) ko call karke verify kiya ki setup kaam kar raha hai
- Issues jo aaye aur fix kiye: API not enabled, IAM permission missing (`roles/aiplatform.user` add kiya), galat region (`us-south1` → `us-central1`)

---

## 3. Local Development Environment

1. Python 3.12 (pyenv se) use kiya
2. `venv` banaya project folder ke andar
3. Zaroori packages install kiye: `google-cloud-aiplatform`, `langchain`, `langgraph`, `langchain-google-vertexai`, `google-cloud-firestore`, `google-cloud-storage`, `fastapi`, `uvicorn`
4. VS Code me interpreter ko venv wala select kiya

---

## 4. Terraform Infrastructure Structure

### Final decided pattern: "Infrastructure-as-root" (simplified, single shared state per environment abhi ke liye)

```
application/
├── infrastructure/
│   └── cloud_storage/          ← ROOT config (reusable module pattern chhod diya, simplicity ke liye)
│       ├── backend.tf          ← terraform{} + backend "gcs" {} (khali, values .hcl se aati hain)
│       ├── provider.tf         ← provider "google" {}
│       ├── main.tf             ← DIRECT resource definition (google_storage_bucket)
│       ├── variables.tf        ← input variables
│       └── outputs.tf          ← outputs
│
└── environments/
    └── dev/
        ├── cloud_storage.hcl    ← backend config VALUES (bucket, prefix)
        └── cloud_storage.tfvars ← variable VALUES (region, bucket_name) — project_id NAHI (secret se aata hai)
```

**Command pattern:**
```bash
cd application/infrastructure/cloud_storage
terraform init -backend-config=../../environments/dev/cloud_storage.hcl
terraform plan -var-file=../../environments/dev/cloud_storage.tfvars
terraform apply -var-file=../../environments/dev/cloud_storage.tfvars -auto-approve
```

### Terraform State Bucket (Bootstrap)
- State store karne ke liye alag GCS bucket: `ai-rag-agent-project-tfstate`
- Chicken-egg problem: is bucket ko khud Terraform se GCS-backend ke through nahi bana sakte
- Solution: `application/bootstrap/main.tf` — LOCAL state use karta hai, sirf ek baar locally run hota hai, sirf tfstate bucket banata hai
- Versioning ON kiya state bucket pe (corruption/loss se recovery ke liye)

### Naming Decisions (kaafi confusion ke baad finalize hui)
- Folder naam: `environments` (PLURAL), `environment` nahi
- Variable naam: `region` (consistent), `location` nahi (jo GCP resource attribute ka naam hai, variable ka nahi)
- `project_id` kabhi `.tfvars` me commit nahi hoti — `TF_VAR_project_id` env var se aati hai (GitHub Secret `GCP_PROJECT_ID` se)

---

## 5. GCP IAM / Service Account Setup

1. Service account banaya: `rag-agent-sa@ai-rag-agent-project.iam.gserviceaccount.com`
2. Roles diye:
   - `roles/aiplatform.user` (Vertex AI/Gemini calls)
   - `roles/datastore.user` (Firestore)
   - `roles/storage.admin` (bucket create/manage — shुरू me `storage.objectAdmin` diya tha jo sirf object-level tha, bucket create ke liye `storage.admin` chahiye)
   - `roles/run.admin`, `roles/artifactregistry.writer`, `roles/iam.serviceAccountUser` (future Cloud Run deployment ke liye)
3. **Service account KEY FILE nahi bana sakte** — organization policy (`constraints/iam.disableServiceAccountKeyCreation`) block karti hai. Isliye **Workload Identity Federation (WIF)** use kiya — bina kisi key file ke, GitHub Actions seedha service account impersonate karta hai.

### Workload Identity Federation Setup
```bash
gcloud iam workload-identity-pools create "github-actions-pool" --project="ai-rag-agent-project" --location="global"

gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="ai-rag-agent-project" --location="global" \
  --workload-identity-pool="github-actions-pool" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='sadaf-jamal-au27/rag-infra-platform'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

gcloud iam service-accounts add-iam-policy-binding rag-agent-sa@ai-rag-agent-project.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/sadaf-jamal-au27/rag-infra-platform"
```

---

## 6. GitHub Repository Setup

### Secrets (Settings → Secrets and variables → Actions)
| Secret | Value |
|---|---|
| `GCP_PROJECT_ID` | `ai-rag-agent-project` |
| `WIF_PROVIDER` | `projects/<NUM>/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider` |
| `WIF_SERVICE_ACCOUNT` | `rag-agent-sa@ai-rag-agent-project.iam.gserviceaccount.com` |

### Environments (Settings → Environments)
- `production` — Required reviewers: khud (Prevent self-review OFF, kyunki solo project hai)

### Branch Protection Rules — 3 rulesets
1. **`main`** (PROD) — Require PR, require approval, restrict push. Sabse strict.
2. **`develop`** (NON-PROD) — Require PR, thoda relaxed.
3. **`release/*`** — Require PR into main, restrict deletion.
4. **`feature/*`** — koi protection nahi (free working branches)

---

## 7. Branching Strategy (Git Flow — lite)

```
feature/xyz  →  develop  →  release/x.x  →  main
   (free)      (non-prod:      (staging)     (prod)
                dev/qa/test)
```

- `feature/*` pe kaam karo, koi restriction nahi
- `feature/*` → PR → `develop`: triggers **Non-Prod Plan**
- `develop` me merge: triggers **Non-Prod Apply** (dev/qa/test automatically)
- `develop` → `release/x.x` → PR → `main`: triggers **Prod Plan**
- `main` me merge: **Prod Apply** sirf MANUAL trigger (`workflow_dispatch`), approval-gated

---

## 8. GitHub Actions Workflows

| Workflow | Trigger | Kya karta hai |
|---|---|---|
| `non_prod-plan.yaml` | PR → `develop` | `terraform plan` (review ke liye) |
| `non_prod.apply.yaml` | Push → `develop` | `terraform apply` automatically |
| `prod_plan.yaml` | PR → `main` | `terraform plan` (prod ke liye) |
| `prod_apply.yaml` | Manual only | `terraform apply`, approval required |

Sab workflows **Workload Identity Federation** se authenticate karte hain (`google-github-actions/auth@v2`), koi key file nahi.

---

## 9. Security Additions (Banking/Healthcare-grade)

- **`security-scan.yml`** — tfsec + Checkov + TFLint, har PR pe automatically chalta hai
- **CMEK encryption** design kiya (KMS module) — abhi implement nahi hua, future ke liye ready hai
- **Custom least-privilege IAM roles** design kiye (broad `roles/editor` jaisa kuch use nahi kiya)
- **Audit logging module** design kiya (DATA_READ/DATA_WRITE logs + locked retention bucket)
- **`.pre-commit-config.yaml`** — local machine pe commit se pehle hi security issues pakadta hai

---

## 10. Common Issues Faced & Fixes (Troubleshooting Log)

| Issue | Fix |
|---|---|
| `gcloud` crash — Python 3.9 not supported | `CLOUDSDK_PYTHON` env var set kiya |
| `ModuleNotFoundError: vertexai` | `pip install google-cloud-aiplatform` |
| `PERMISSION_DENIED` Vertex AI | `roles/aiplatform.user` role diya |
| Galat region `us-south1` | `us-central1` kiya |
| Model `gemini-1.5-flash-002` not found | `gemini-2.5-flash` use kiya (purana deprecated tha) |
| Service account key creation blocked | Workload Identity Federation use kiya (no keys) |
| `Unexpected block: backend` error | `backend` block module (`infrastructure/`) ke andar galti se chala gaya tha — root config me hona chahiye |
| GitHub Actions pipeline trigger nahi hui | Path filter mismatch — actual files `application/environment/...` (singular, wrapper folder) me thi, workflow `environments/...` dhoondh raha tha |
| `Matrix vector 'resource' does not contain any values` | Per-resource subfolder missing thi — baad me simplify karke single-shared-state pattern pe switch kiya |
| `terraform fmt -check` fail | `=` signs properly align nahi the — manually fix kiya ya `fmt` step hata diya |
| State bucket "doesn't exist" | Bootstrap Terraform config (local state) se banaya |
| State lock stuck (`conditionNotMet`) | `terraform force-unlock <LOCK_ID>` chalaya |
| `storage.buckets.create` permission denied | `roles/storage.objectAdmin` se `roles/storage.admin` upgrade kiya |
| GitHub push rejected — file 109MB | `.terraform/` folder galti se commit ho gaya tha — `.gitignore` fix kiya, `git rm --cached`, `commit --amend` |

---

## 11. Current Status

✅ GCP project + Gemini API working
✅ Terraform infra structure (cloud_storage) — plan + apply working via CI/CD
✅ GitHub Actions pipelines (non-prod plan/apply) functional
✅ Workload Identity Federation (no service account keys)
✅ Branch protection + environments configured

## 12. Next Steps

- [ ] Baaki resources add karo: `project_iam`, `firestore`, `artifact_registry`, `workload_identity` (isi pattern me)
- [ ] `qa`, `test`, `prod` environments banao
- [ ] RAG agent application code likho: PDF ingestion → chunking → embeddings → Firestore vector search → LangGraph agent → FastAPI → Dockerfile → Cloud Run deploy
- [ ] Security modules (KMS, audit logging, custom IAM roles) ko actually implement/wire karo

---

## Quick Reference Commands

```bash
# Local Terraform run (agar kabhi zarurat pade)
export TF_VAR_project_id="ai-rag-agent-project"
cd application/infrastructure/cloud_storage
terraform init -backend-config=../../environments/dev/cloud_storage.hcl
terraform plan -var-file=../../environments/dev/cloud_storage.tfvars

# Stuck lock fix
terraform force-unlock <LOCK_ID>

# gcloud auth check
gcloud auth list
gcloud config get-value project
```