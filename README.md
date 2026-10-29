# DevOps Challenge — Hello World Next.js

A small Next.js service packaged as a non-root Docker image and prepared for deployment to Google Kubernetes Engine (GKE) using Kustomize and Argo CD.

> **Status:** This repository is designed to be validated locally without creating cloud resources. The GCP infrastructure, GitHub Actions workflows, and Argo CD deployment path require the configuration described below before they can run end to end. No Terraform apply or paid cloud deployment is required for this submission.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       ├── app-ci.yaml
│       └── infra-ci.yaml
├── application/                 # Next.js app and Dockerfile
├── architecture/                # Editable diagram sources and exported images
├── infra/                       # Terraform for GCP infrastructure
├── k8s/
│   ├── base/                    # Reusable Deployment and Service
│   ├── overlays/production/     # Production-specific resources
│   └── argocd/                  # Argo CD Application and install guidance
├── docker-compose.yml
├── .env.example
├── ARCHITECTURE.md
└── README.md
```

## Application endpoints

- `/` — Hello World page.
- `/api/health` — BFF health endpoint returning HTTP 200 and `{"status":"ok"}`.

Kubernetes readiness and liveness probes use `/api/health`.

## Run locally

Requirements: Docker Desktop or Docker Engine with the Compose plugin.

```bash
docker compose up --build -d
docker compose ps
curl -i http://localhost:3000/api/health
```

Expected health response:

```json
{"status":"ok"}
```

Stop the local service:

```bash
docker compose down
```

You can also run the application without Docker:

```bash
cd application
npm ci
npm run lint
npm run build
npm run dev
```

The local Compose setup does not require environment variables. `.env.example` records that no local runtime settings are required; do not put credentials or tokens in it.

## Infrastructure

Terraform in `infra/` defines the intended GCP network, GKE cluster/node pool, Artifact Registry repository, and Cloud Logging sink/bucket. The sample variable file is `infra/terraform.tfvars.example`.

Local static checks, which do not create cloud resources:

```bash
cd infra
terraform init -backend=false
terraform fmt -check -recursive .
terraform validate
```

The Terraform configuration declares a GCS backend. For a real plan, first create a dedicated state bucket with object versioning, then configure GitHub variable `TF_STATE_BUCKET` and the Terraform WIF identity. The local validation commands above intentionally disable the backend. **Do not enable or run Terraform apply for this assignment.**

## CI/CD and GitOps

### Application CI

`.github/workflows/app-ci.yaml` runs lint/build checks on pushes to `main` and pull requests. On pull requests it also renders the production Kustomize overlay. On pushes to `main`, it authenticates to Google Cloud using Workload Identity Federation, builds and scans an image tagged with the full Git commit SHA, pushes it, updates `k8s/overlays/production/kustomization.yaml`, and renders the updated manifests before committing the image reference.

Configure these GitHub Actions repository variables:

- `GCP_PROJECT_ID` — GCP project ID.
- `GCP_WIF_PROVIDER` — full Workload Identity Provider resource name.
- `GCP_APP_WIF_SERVICE_ACCOUNT` — narrowly scoped service account for image publishing.
- `GCP_TF_WIF_SERVICE_ACCOUNT` — separate service account for Terraform operations.
- `GAR_LOCATION` — Artifact Registry location; keep it consistent with the Terraform region (`asia-southeast1` by default).
- `GAR_REPOSITORY` — Artifact Registry repository ID (`hello-world-production` with the default environment).
- `TF_STATE_BUCKET` — pre-created, versioned GCS bucket used by the Terraform backend.
- `TF_APPLY_ENABLED` — set to `true` only after remote state and GitHub environment protections are ready; leave unset for this assignment.

The application identity should have Artifact Registry Writer only on the application repository. The Terraform identity needs permissions for the declared infrastructure, service-account/IAM management, permission to attach the GKE node account, and object read/write access on the dedicated state bucket. Keep those identities separate; do not grant project Owner. Configure Workload Identity Federation trust to restrict each identity to the intended repository, branch, and workflow. Do not store service-account JSON keys in GitHub secrets.

The workflow commits the new image tag to the same Git repository. GitHub's built-in `GITHUB_TOKEN` does not start another workflow run when it pushes this commit, so the publish job renders the updated Kustomize manifests before committing. Argo CD sees the Git change and deploys it. The workflow does **not** use `kubectl` or connect to the Kubernetes API.

### Terraform CI

`.github/workflows/infra-ci.yaml` runs `terraform fmt`, initialization, and validation on infrastructure pull requests and pushes. It runs a plan only when the remote state bucket and Terraform WIF variables are configured. The GCS backend is declared in `infra/versions.tf`; create a dedicated state bucket with object versioning before configuring the `TF_STATE_BUCKET` repository variable. The apply job is disabled unless `TF_APPLY_ENABLED` is set to `true`, runs only after a push to `main`, and targets the GitHub `production-deployment` environment. Configure required reviewers and branch restrictions on that environment before enabling apply. Do not apply infrastructure for this assignment.

The plan is generated against the configured remote state. The protected-environment approval is an external GitHub setting; the workflow cannot enforce reviewers unless that environment is configured with required reviewers. Keep apply disabled until the backend and environment protections are ready.

### Argo CD

`k8s/argocd/helmfile.yaml` and `values.yaml` declare a pinned Argo CD Helm installation. Verify that the repository URL in `k8s/argocd/application.yaml` matches the submitted repository; the Application watches `k8s/overlays/production`. Automated sync, pruning, and self-healing are enabled:

- **Auto-sync:** applies Git changes.
- **Prune:** removes managed resources removed from Git.
- **Self-heal:** reconciles manual drift in the cluster back to Git.
- **Health:** the Kubernetes Deployment becomes healthy when its Pods pass readiness checks against `/api/health`.

Argo CD installation/bootstrap is documented in `k8s/argocd/README.md`. The Argo CD controller, rather than application CI, is responsible for applying manifests to the cluster. Roll back by reverting the image-tag commit in Git.

## Required setup before end-to-end cloud CI/CD

1. Create/configure the GCP project and enable required APIs (GKE, Compute Engine, Artifact Registry, Cloud Logging, Cloud Storage, and IAM).
2. Create a dedicated, versioned GCS bucket for Terraform state and configure `TF_STATE_BUCKET`.
3. Configure Workload Identity Federation with separate app-publishing and Terraform service accounts; grant the Terraform identity only the infrastructure permissions it needs, including permission to attach the GKE node service account. The node service account itself receives GKE's baseline node role and Artifact Registry Reader from Terraform.
4. Ensure Terraform's Artifact Registry repository name matches `GAR_REPOSITORY`.
5. Install Argo CD from the pinned Helmfile definition, then apply the Application once as a bootstrap operation.
6. Configure GitHub branch protection and required reviewers for the `production-deployment` environment before setting `TF_APPLY_ENABLED=true`.
7. Test the app workflow and confirm the image-tag commit is reconciled by Argo CD.

These steps are documented design/setup work; they do not imply that a cloud deployment has been performed.

## Security and operational choices

- Multi-stage Docker build with a non-root runtime user.
- Kubernetes container drops Linux capabilities, disallows privilege escalation, and disables service-account token automounting.
- Readiness/liveness probes use the BFF health endpoint.
- CPU/memory requests and limits are declared.
- Production overlay defines an HPA, PDB, and GKE Ingress.
- Trivy scans the built application image and blocks pushes when fixed HIGH or CRITICAL vulnerabilities are found.
- Secrets and Terraform state files must not be committed.
- The application pipeline builds/pushes an image and updates Git; it never invokes `kubectl` against the cluster.

## Known limitations / follow-up work

- The manifests and Terraform are infrastructure-as-code definitions; the cloud infrastructure has not been applied.
- GitHub Actions needs the repository variables and GCP Workload Identity Federation configuration listed above.
- Argo CD must be installed and bootstrapped in the target cluster before it can reconcile the Application.
- The Terraform apply job remains disabled until a GCS backend is configured, `TF_APPLY_ENABLED=true` is set, and required reviewers are configured on `production-deployment`.
- The architecture folder contains editable Mermaid sources and an SVG overview export; update the export whenever you change the diagrams.

## Optional operational checks

### Pod recovery exercise

Run this only against a disposable, non-production cluster. Set the context explicitly and confirm the destructive action before deleting one Pod:

```bash
set -euo pipefail
: "${KUBE_CONTEXT:?Set KUBE_CONTEXT to a disposable cluster context}"
: "${CHAOS_CONFIRM:?Set CHAOS_CONFIRM=DELETE_ONE_POD_IN_DISPOSABLE_CLUSTER after checking the context}"
[[ "$CHAOS_CONFIRM" == "DELETE_ONE_POD_IN_DISPOSABLE_CLUSTER" ]]
case "$KUBE_CONTEXT" in
  *prod*|*production*|*live*) echo "Refusing production-like context: $KUBE_CONTEXT"; exit 1 ;;
esac
POD="$(kubectl --context "$KUBE_CONTEXT" -n production get pods -l app=hello-world-nextjs -o jsonpath='{.items[0].metadata.name}')"
test -n "$POD"
kubectl --context "$KUBE_CONTEXT" -n production get pod "$POD"
kubectl --context "$KUBE_CONTEXT" -n production delete pod "$POD" --wait=false
kubectl --context "$KUBE_CONTEXT" -n production rollout status deployment/hello-world-nextjs --timeout=180s
curl --fail "${SERVICE_URL:?Set SERVICE_URL to the test service URL}/api/health"
```

This checks recovery from a single Pod failure; it does not simulate node, zone, or dependency failures. The context-name guard is a precaution, not a substitute for verifying the target cluster.

### Recovery approach

The application is stateless. Roll back a bad release by reverting the Git commit that changed the image SHA; Argo CD reconciles the prior image. There is no application data volume to back up.

For Terraform state, use the dedicated GCS backend bucket with object versioning enabled. Before state recovery, stop concurrent Terraform runs, identify the prior object generation, copy it to a separate recovery object, and inspect the recovered state with `terraform state list` before restoring it as the active state. Run and review a plan before any apply. Do not treat the log-export bucket as a backup of Terraform state.
