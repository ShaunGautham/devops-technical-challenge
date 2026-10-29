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

The local Compose setup does not require environment variables. `.env.example` documents the non-secret configuration knobs; do not put credentials or tokens in it.

## Infrastructure

Terraform in `infra/` defines the intended GCP network, GKE cluster/node pool, Artifact Registry repository, and Cloud Logging sink/bucket. The sample variable file is `infra/terraform.tfvars.example`.

Local static checks, which do not create cloud resources:

```bash
cd infra
terraform init -backend=false
terraform fmt -check -recursive .
terraform validate
```

To generate a plan against a real GCP project, configure credentials and a `terraform.tfvars` file from the example. Review the plan carefully. **Do not run `terraform apply` for this assignment.** A production setup should use a remote, locked state backend (for example, a dedicated GCS bucket) rather than a developer's local state.

## CI/CD and GitOps

### Application CI

`.github/workflows/app-ci.yaml` runs lint/build checks on pushes to `main` and pull requests. On pushes to `main`, it authenticates to Google Cloud using Workload Identity Federation, builds and pushes an image tagged with the full Git commit SHA, and updates the image reference in `k8s/overlays/production/kustomization.yaml`. The generated bot commit triggers validation but does not trigger another image publish.

Configure these GitHub Actions repository variables:

- `GCP_PROJECT_ID` — GCP project ID.
- `GCP_WIF_PROVIDER` — full Workload Identity Provider resource name.
- `GCP_WIF_SERVICE_ACCOUNT` — service account email used by GitHub Actions.
- `GAR_LOCATION` — Artifact Registry location; keep it consistent with the Terraform region (`asia-southeast1` by default).
- `GAR_REPOSITORY` — Artifact Registry repository ID (`hello-world-production` with the default environment).

The GitHub Actions service account should have only the permissions needed to push to the specific Artifact Registry repository. Configure Workload Identity Federation trust so only the intended GitHub repository/ref can impersonate it. Do not store service-account JSON keys in GitHub secrets.

The workflow commits the new image tag to the same Git repository. Argo CD sees that Git change and deploys it. The workflow does **not** use `kubectl` or connect to the Kubernetes API.

### Terraform CI

`.github/workflows/infra-ci.yaml` runs `terraform fmt`, initialization, and validation on infrastructure pull requests and pushes. It runs a plan when the GCP project and WIF variables are configured. A main-branch push also reaches an apply job associated with the GitHub `production` environment. That environment pauses for approval only if required reviewers or other protection rules are configured in GitHub settings. The repository has no remote Terraform backend configured, so do not use the apply job until a remote backend with locking and environment approval are in place. Do not apply infrastructure for this assignment.

For a production team, use a remote state backend, restrict who can approve infrastructure changes, and require a reviewed plan before any separately authorized apply.

### Argo CD

`k8s/argocd/helmfile.yaml` and `values.yaml` declare a pinned Argo CD Helm installation. Set the repository URL in `k8s/argocd/application.yaml`; it declares an Argo CD Application that watches `k8s/overlays/production`. Automated sync, pruning, and self-healing are enabled:

- **Auto-sync:** applies Git changes.
- **Prune:** removes managed resources removed from Git.
- **Self-heal:** reconciles manual drift in the cluster back to Git.
- **Health:** the Kubernetes Deployment becomes healthy when its Pods pass readiness checks against `/api/health`.

Argo CD installation/bootstrap is documented in `k8s/argocd/README.md`. The Argo CD controller, rather than application CI, is responsible for applying manifests to the cluster. Roll back by reverting the image-tag commit in Git.

## Required setup before end-to-end cloud CI/CD

1. Create/configure the GCP project and enable required APIs (GKE, Compute Engine, Artifact Registry, Cloud Logging, and Cloud Storage).
2. Configure Workload Identity Federation and a narrowly scoped GitHub Actions service account.
3. Ensure Terraform's Artifact Registry repository name matches `GAR_REPOSITORY`.
4. Set `repoURL` in `k8s/argocd/application.yaml`, install Argo CD from the pinned Helmfile definition, then apply the Application once as a bootstrap operation.
5. Configure GitHub branch protection and review rules as appropriate.
6. Test the app workflow and confirm the image-tag commit is reconciled by Argo CD.

These steps are documented design/setup work; they do not imply that a cloud deployment has been performed.

## Security and operational choices

- Multi-stage Docker build with a non-root runtime user.
- Kubernetes container drops Linux capabilities, disallows privilege escalation, and disables service-account token automounting.
- Readiness/liveness probes use the BFF health endpoint.
- CPU/memory requests and limits are declared.
- Production overlay defines an HPA, PDB, and GKE Ingress.
- Secrets and Terraform state files must not be committed.
- The application pipeline builds/pushes an image and updates Git; it never invokes `kubectl` against the cluster.

## Known limitations / follow-up work

- The manifests and Terraform are infrastructure-as-code definitions; the cloud infrastructure has not been applied.
- GitHub Actions needs the repository variables and GCP Workload Identity Federation configuration listed above.
- Argo CD must be installed and bootstrapped in the target cluster before it can reconcile the Application.
- The Terraform apply job requires a remote state backend with locking and required reviewers on the GitHub `production` environment before it is safe to use.
- The architecture folder contains editable Mermaid sources and an SVG overview export; update the export whenever you change the diagrams.
