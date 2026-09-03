# coredns-patch

OKDP chart that patches the kube-system CoreDNS configuration for local development: a
Job inserts a `template` block in the Corefile so that every name under the platform
ingress suffix (`global.okdp.ingress.suffix`), the suffix itself included, is answered
inside the cluster, for every query type, with a CNAME to the ingress controller
Service. Pods then reach the platform ingresses by their public names, and no query of
the suffix (AAAA included) reaches the host resolver, which may not know it. The Job is
idempotent: it replaces any template block of the suffix and restarts CoreDNS only when
the Corefile changed.

It renders `oci://quay.io/okdp/charts/coredns-patch` 0.1.0, vendored under `vendor/`
(see `vendor.yaml`), for its ServiceAccount and RBAC. Its Job, which answers only `A`
queries (an `AAAA` lookup then leaves the cluster and can time out), is dropped:
`templates/job.yaml` replaces it, with the block of `templates/_values.tpl`. The Job
name carries a hash of the block (a Job spec is immutable), so a changed block runs
again on upgrade.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `ingressService` | `ingress-nginx-ingress-nginx-controller.ingress-nginx.svc.cluster.local` | FQDN of the ingress controller Service: `<ingress-nginx release>-controller.<namespace>.svc.cluster.local`. |

Platform values read: `global.okdp.ingress.suffix` (required).

The Job, ServiceAccount and RBAC live in `kube-system` with fixed names (the Job's
with its hash suffix), whatever the release namespace: install it once per cluster
(component `10-coredns-patch`, namespace `kube-system`).

## Changes from the KuboCD package

- `ingressService` defaults to the controller Service of the `10-ingress-nginx`
  component (release `ingress-nginx-ingress-nginx`); it was
  `ingress-nginx-controller.ingress-nginx…` (the sandbox set `ingress-nginx-main-controller…`).
- Every query type of the suffix is answered in the cluster (was `A` only), and a
  Corefile patched by the former package is updated.

## Tests

```sh
helm dependency build packages/system/coredns-patch
for f in packages/system/coredns-patch/ci/*-values.yaml; do
  helm lint packages/system/coredns-patch -f "$f"
  helm template kube-system-coredns-patch packages/system/coredns-patch -n kube-system -f "$f" >/dev/null
done
scripts/vendor-charts.sh --check packages/system/coredns-patch
```
