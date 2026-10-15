# ingress-nginx

OKDP package of the [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/),
in one of three deployment modes:

- `nodePort`: NodePort Service on `httpPort`/`httpsPort` (kind clusters, the sandbox);
- `hostPort`: host networking, ports 80/443 on every node, no Service;
- `metallb`: LoadBalancer Service on the fixed IP `endpoint`.

A package in the okdp-compiler format: `Chart.yaml` names the upstream chart
`ingress-nginx` 4.15.1 (controller v1.15.1) (https://kubernetes.github.io/ingress-nginx,
not published as an OCI chart), rendered from its repository; `values.cel.yaml` computes
its values from the parameters (`config.schema.json`), over OKDP's defaults
`ingress-nginx.defaults.yaml` (`okdp.yaml`).
SSL passthrough is off, snippet annotations are off, the admission webhook is on (its
certificate Jobs are pre/post-install and pre/post-upgrade hooks, Argo CD PreSync/PostSync).

**The ingress-nginx project is retired**: 4.15.1 (March 2026) is its final release, the
repository is archived, and no fix, including for security vulnerabilities, will follow
([announcement](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)). The
chart stays as the sandbox ingress until the platform moves to a Gateway API
implementation; do not expose it to untrusted users.

| Former module | Now | Compiled when |
|---|---|---|
| `main` | chart `ingress-nginx` (kubernetes/ingress-nginx 4.15.1) | always |

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `mode` | `nodePort` | `nodePort`, `hostPort` or `metallb`. |
| `endpoint` | `""` | LoadBalancer IP (required in `metallb` mode). |
| `httpPort` / `httpsPort` | `30080` / `30443` | Node ports in `nodePort` mode. |

Platform values read: `global.okdp.ingress.className` (default `nginx`): the IngressClass
created, the one every platform chart uses.

The controller Service is `<release>-controller` (component `10-ingress-nginx` in
namespace `ingress-nginx`: `ingress-nginx-ingress-nginx-controller`), the value of the
`coredns-patch` chart's `ingressService`.

## Upstream values

Any value of the `ingress-nginx` chart can be set per instance under
`upstream.ingress-nginx`, merged over the values computed from the parameters
(`upstream` in `okdp.yaml`):

```yaml
upstream:
  ingress-nginx:
    controller:
      image: {registry: mirror.example.org}
      resources: {requests: {cpu: 200m, memory: 256Mi}}
      tolerations: [{key: dedicated, operator: Exists, effect: NoSchedule}]
      config: {proxy-body-size: 64m}          # added to the controller ConfigMap
```

The paths the platform relies on are refused: names, the IngressClass, the
exposure chosen by `mode` (Service, node ports, host networking, the MetalLB
IP), the hardening above (SSL passthrough, snippet annotations and the
annotation risk level, the admission webhook), autoscaling, RBAC: see
`protect` in `okdp.yaml`, where the `metallb.universe.tf/` Service
annotations, whose keys contain dots, are written in brackets (also listed in
the schema description); set the MetalLB IP with `endpoint`. The mapping sets
no list, so a list replaces the chart's. No key or value may contain `{{` (the
schema and okdp-compile both refuse it).

## Changes from the KuboCD package

- SSL passthrough is off (`--enable-ssl-passthrough` was on): no platform Ingress uses
  `nginx.ingress.kubernetes.io/ssl-passthrough`. The admission webhook stays reachable
  from every pod: chart 4.15.1 has no option to restrict it with a NetworkPolicy
  (`controller.networkPolicy` opens the webhook port to all sources).

- The IngressClass follows `global.okdp.ingress.className` (was the chart default `nginx`).
- Objects are named after the release (the controller Service was `ingress-nginx-main-controller`).

## Known gaps

What okdp-lib-chart did to the rendered objects and values that the
okdp-compiler format cannot express:

- the values ConfigMap `<release>-ingress-nginx-values` (`okdp.io/vendor-values`)
  is gone: the compiled values replace it. They are the values the chart
  receives, before its templates write `registry` into `controller.image` and
  `controller.admissionWebhooks.patch.image` (`merge` with `global.image`),
  which that ConfigMap showed.

Nothing else: the ingress-nginx objects already carry `app.kubernetes.io/instance`.
What the instance publishes (its usage) is `okdp.instance.yaml`, next to the
compiled umbrella chart, no longer the descriptor ConfigMap `<release>-okdp`.

## Tests

`ci/platform.yaml` holds the platform values of every case; `metallb` has its own
suffix and IngressClass (`ci/metallb-platform.yaml`); `metallb-no-endpoint` and
`protected-upstream` must fail.

```sh
scripts/compile-charts.sh catalog/ingress-nginx/4.15.1-1.0.0   # compile, check and render ci/*-values.yaml
```
