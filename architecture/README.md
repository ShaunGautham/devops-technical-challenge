# Architecture diagrams

`solution.svg` is a four-block overview of the solution. Its blocks separate:

1. Terraform-defined GCP infrastructure and resource connections.
2. Kubernetes workload objects and the user traffic path.
3. Application CI from a source change through image publishing and Argo CD rollout.
4. Repository folders and their purpose.

`solution.mmd` is the editable Mermaid source for that overview. `repository-structure.mmd` and `repository-structure.svg` provide a larger standalone view of the repository layout.

The diagrams describe the configuration in this repository. Terraform resources are not deployed for the assignment. The Terraform state bucket is a prerequisite and is not the log-export bucket. The current Ingress has no TLS configuration, so the traffic block does not claim HTTPS.

Update the Mermaid source and SVG together when the architecture changes. Check that labels and arrows remain legible and match Terraform, Kubernetes manifests, and GitHub Actions workflows.
