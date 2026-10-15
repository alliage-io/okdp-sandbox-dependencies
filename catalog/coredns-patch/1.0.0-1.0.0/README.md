# coredns-patch

OKDP package that patches the kube-system CoreDNS configuration for local development: a
Job inserts a `template` block in the Corefile so that every name under the platform
ingress suffix (`global.okdp.ingress.suffix`), the suffix itself included, is answered
inside the cluster, for every query type, with a CNAME to the ingress controller
Service. Pods then reach the platform ingresses by their public names, and no query of
the suffix (AAAA included) reaches the host resolver, which may not know it. The Job is
idempotent: it replaces any template block of the suffix and restarts CoreDNS only when
the Corefile changed.

A package in the okdp-compiler format, with no upstream chart (no dependency in
`Chart.yaml`): `okdp.yaml` computes the Job, its ServiceAccount and its RBAC as OKDP's own
objects (its `objects` section, rendered by the compiled umbrella chart,
`okdp.objects.yaml`), from the parameters below (`config.schema.json`). The former
module's chart, `oci://quay.io/okdp/charts/coredns-patch`, is no longer used: its Job
answered only `A` queries (an `AAAA` lookup then leaves the cluster and can time out),
and the version whose ServiceAccount and RBAC the previous package rendered, 0.2.0 (Role
restricted to the `coredns` Deployment), was never published; its three RBAC objects are
written in `okdp.yaml` instead. The Job name carries a hash of the block and the image (a
Job spec is immutable), so a changed block or image runs again on upgrade.

| Former module | Now | Compiled when |
|---|---|---|
| `main` | OKDP's objects: ServiceAccount `coredns-config-sa`, Role and RoleBinding (were the chart `coredns-patch`'s) | always |
| (wrapper `templates/job.yaml`) | OKDP's objects: the Job `coredns-config-job-<hash>` | always |

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `ingressService` | `ingress-nginx-ingress-nginx-controller.ingress-nginx.svc.cluster.local` | FQDN of the ingress controller Service: `<ingress-nginx release>-controller.<namespace>.svc.cluster.local`. |
| `image.repository` / `image.tag` / `image.digest` | `quay.io/okdp/sandbox-images/kubectl` / `latest` / `sha256:cd354d5b…` | Image of the patch Job (needs kubectl, bash, awk and jq). `digest`, when set, wins over `tag`: the repository only publishes `latest`, so the default is pinned by digest. `digest` is `sha256:<64 hex>` or empty (checked by the schema). |

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
- The Job image is a value, pinned by digest by default (was `kubectl:latest`).
- The Role lets the Job patch the `coredns` Deployment only
  (`resourceNames: [coredns]`); the chart coredns-patch 0.1.0 let it patch every
  kube-system Deployment.
- The ServiceAccount, Role and RoleBinding carry OKDP's labels
  (`app.kubernetes.io/name: coredns-patch`, `okdp.io/instance`...), no longer the
  chart's `commonLabels` alone.

## Known gaps

What okdp-lib-chart did to the rendered objects and values that the
okdp-compiler format cannot express:

- the values ConfigMap `<release>-coredns-patch-values` (`okdp.io/vendor-values`) is
  gone. What the instance publishes (its usage) is `okdp.info.yaml`, next to the
  compiled umbrella chart, no longer the descriptor ConfigMap `<release>-okdp`.

## Tests

`ci/platform.yaml` holds the platform values of every case; `custom` has its own
ingress suffix (`ci/custom-platform.yaml`); `no-image` must fail.

```sh
scripts/compile-charts.sh catalog/coredns-patch/1.0.0-1.0.0   # compile, check and render ci/*-values.yaml
```
