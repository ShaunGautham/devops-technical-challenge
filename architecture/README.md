# Architecture diagram source and exports

The diagrams are maintained as editable Mermaid source files and committed
with SVG exports:

- `solution.mmd` → `solution.svg`: GCP resources, Kubernetes traffic and
  objects, application GitOps flow, and Terraform workflow boundary.
- `repository-structure.mmd` → `repository-structure.svg`: repository layout
  and the purpose of each area.

When editing a diagram, update its `.mmd` source and export the matching SVG
from a Mermaid-compatible editor or renderer. Review the SVG after export to
confirm labels and arrows remain legible and match the source. Keep the diagrams
aligned with Terraform, Kubernetes manifests, and GitHub Actions workflows.

The solution diagram describes the intended Terraform-managed architecture.
The assignment does not require applying Terraform or deploying to a real
cluster.
