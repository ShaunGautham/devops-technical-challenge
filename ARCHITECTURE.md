# Architecture

## Scope

This document describes the resources and delivery flow encoded in the repository.
The take-home submission does not apply Terraform or deploy the application to a
real cluster. The diagrams represent the intended design, not evidence of a live
deployment.

## Infrastructure and resource connections

Terraform in `infra/` defines a custom VPC and regional subnet in
`asia-southeast1`, with separate secondary ranges for GKE Pods and Services. It
defines a regional GKE cluster and a separate autoscaling node pool. The node
pool is configured for one to two nodes total across the region, automatic
repair and upgrade, and GKE metadata for Workload Identity.

Terraform also defines a private Artifact Registry repository named
`hello-world-production`. GitHub Actions pushes the application image to this
repository using a narrowly scoped Workload Identity Federation identity. GKE
nodes use a dedicated service account with Artifact Registry Reader and GKE's
default node service-account role. The service-account ID is kept within
Google's naming limit. The Terraform execution identity is separate from the
application publishing identity and must be allowed to attach the node account.

GKE container logs are selected by a Cloud Logging project sink and exported to
a GCS bucket. The bucket enables uniform bucket-level access, public access
prevention, object versioning, and a 90-day lifecycle rule. The logging sink has
a unique writer identity with object-creation access to the bucket.

## Kubernetes resources and request flow

An internet request reaches the GKE-managed external load balancer created by the
GKE Ingress controller from the `Ingress` resource. The Ingress routes to the
`hello-world-nextjs` `Service` on port 3000. The Service selects Pods managed by
the `Deployment` in namespace `production`.

The Deployment starts with two replicas and uses a rolling update with
`maxUnavailable: 0` and `maxSurge: 1`. This keeps old replicas available until
replacements pass readiness checks; one temporary extra Pod provides rollout
capacity. The production overlay adds an HPA that
can scale between two and five replicas at 70% average CPU utilization, and a
PDB that requests at least one available Pod during voluntary disruptions. The
HPA needs a working cluster metrics source. Readiness and liveness probes call
`/api/health`; readiness controls whether the Service sends traffic to a Pod.

The Pods run as UID 1001, drop Linux capabilities, disallow privilege
escalation, and do not mount a Kubernetes service-account token. CPU and memory
requests and limits are set in the Deployment.

## GitOps installation and reconciliation

`k8s/argocd/helmfile.yaml` defines the pinned Argo CD Helm chart and creates the
`argocd` namespace. An operator installs it once with Helmfile, then applies
`k8s/argocd/application.yaml` once to bootstrap the Argo CD Application. That
Application watches the `main` branch at `k8s/overlays/production`. Argo CD
reads the manifests from Git and applies them through its in-cluster Kubernetes
access. A private Git repository would require read credentials configured in
Argo CD; no Git credential is stored in this repository.

After bootstrap, automated sync applies Git changes, self-heal reconciles live
drift, and prune removes managed resources deleted from Git. To roll back an
application release, revert the commit that changed the image tag.

## Application pipeline

On pull requests, `.github/workflows/app-ci.yaml` installs the locked Node
dependencies, runs lint and build, and previews the production Kustomize
manifests. On a push to `main`, it authenticates to Google Cloud using the app
publishing Workload Identity Federation identity, builds the Docker image, scans
for HIGH and CRITICAL vulnerabilities, then pushes it to Artifact Registry with
the full source commit SHA as the tag. It uses `kustomize edit set image` to
update `newName` and `newTag` in `k8s/overlays/production/kustomization.yaml`,
renders the updated manifests, and commits the change to Git.

Argo CD reads that Git commit and reconciles the cluster. The GitHub built-in
`GITHUB_TOKEN` push does not trigger a second workflow run; the generated overlay
is validated in the original publish run. Pushes that change only
`k8s/overlays/production/kustomization.yaml` are also filtered before a runner is
allocated. CI does not hold Kubernetes credentials and does not apply manifests
to the cluster. Kubernetes pulls the image from Artifact Registry and rolls out
the updated Deployment. The starting `configure-ci` tag in the overlay is a
placeholder; a successful first image publish must replace it before the
application can start successfully.

## Infrastructure workflow and deployment boundary

`.github/workflows/infra-ci.yaml` runs Terraform formatting, initialization,
and validation on infrastructure changes. When the remote state bucket and
Terraform Workload Identity variables are configured, it also plans against the
GCS backend declared in `infra/versions.tf`. The state bucket must be created
beforehand and have object versioning enabled. Apply is disabled unless
`TF_APPLY_ENABLED=true`; when enabled, it runs on a main-branch push and targets
the GitHub `production-deployment` environment. The approval gates a fresh plan
and apply in that job; it does not approve a saved plan artifact from the earlier
preview job. Required reviewers and branch restrictions must be configured on
that environment in GitHub settings. For this take-home, do not enable apply or
create cloud resources.

## Repository layout and rationale

- `application/` keeps the Next.js source, lockfile, Dockerfile, and Docker
  context together so the image build is self-contained.
- `infra/` keeps GCP infrastructure definitions and variables separate from
  application and cluster configuration.
- `k8s/base/` contains reusable Deployment and Service resources.
- `k8s/overlays/production/` contains production-specific namespace, ingress,
  scaling, availability, and image settings.
- `k8s/argocd/` contains the Argo CD installation definition and the
  Application bootstrap manifest.
- `.github/workflows/` contains the application and infrastructure pipelines.
- `architecture/` contains editable Mermaid sources and their SVG exports.
- `docker-compose.yml` provides a local container run path; `.env.example`
  documents the absence of required local settings without storing secrets.
- `README.md` contains setup and run instructions; this file explains the
  architecture and its trade-offs.

The solution diagram is maintained in `architecture/solution.mmd` and exported
to `architecture/solution.svg`. The repository layout diagram is maintained in
`architecture/repository-structure.mmd` and exported to
`architecture/repository-structure.svg`. Update both a Mermaid source and its
SVG export together when the implementation changes.

## Design trade-offs and limitations

- GKE, Artifact Registry, Cloud Logging, and GCS provide a single-cloud target
  for the assignment.
- Kustomize overlays separate shared workload resources from production
  configuration.
- Commit-SHA image tags make the deployed image traceable and support rollback
  through Git history.
- Workload Identity Federation avoids long-lived GCP keys in GitHub Actions.
- Separate app-publishing and infrastructure identities keep registry write
  access away from the Terraform deployment role.
- The diagrams show Terraform-defined resources; no cloud infrastructure has
  been applied for this submission.
- A pre-created versioned state bucket, environment protection, Terraform
  permissions, and GCP/GitHub identity setup remain deployment prerequisites.
