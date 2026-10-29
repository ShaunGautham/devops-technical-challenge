# Argo CD bootstrap

Install Argo CD from the pinned Helmfile release definition:

```sh
helmfile -f k8s/argocd/helmfile.yaml sync
```

Verify `spec.source.repoURL` in `application.yaml` matches this repository's
clone URL, then bootstrap the Application once:

```sh
kubectl apply -f k8s/argocd/application.yaml
```

After bootstrap, Argo CD watches `k8s/overlays/production` and handles
application deployment. CI does not use Kubernetes credentials. Configure a
real ingress and TLS for the Argo CD server before exposing it outside a
trusted network; the example Helm values keep it as a ClusterIP service.
