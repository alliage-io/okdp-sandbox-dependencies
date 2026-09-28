# ingress-nginx

OKDP chart of the [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/),
in one of three deployment modes:

- `nodePort`: NodePort Service on `httpPort`/`httpsPort` (kind clusters, the sandbox);
- `hostPort`: host networking, ports 80/443 on every node, no Service;
- `metallb`: LoadBalancer Service on the fixed IP `endpoint`.

It renders the upstream chart `ingress-nginx` 4.15.1 (controller v1.15.1)
(https://kubernetes.github.io/ingress-nginx, not published as an OCI chart), vendored
under `vendor/` (see `vendor.yaml`), with values computed in `templates/_values.tpl`.
SSL passthrough is off, snippet annotations are off, the admission webhook is on (its
certificate Jobs are pre/post-install and pre/post-upgrade hooks, Argo CD PreSync/PostSync).

**The ingress-nginx project is retired**: 4.15.1 (March 2026) is its final release, the
repository is archived, and no fix, including for security vulnerabilities, will follow
([announcement](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)). The
chart stays as the sandbox ingress until the platform moves to a Gateway API
implementation; do not expose it to untrusted users.

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

## Changes from the KuboCD package

- SSL passthrough is off (`--enable-ssl-passthrough` was on): no platform Ingress uses
  `nginx.ingress.kubernetes.io/ssl-passthrough`. The admission webhook stays reachable
  from every pod: chart 4.15.1 has no option to restrict it with a NetworkPolicy
  (`controller.networkPolicy` opens the webhook port to all sources).

- The IngressClass follows `global.okdp.ingress.className` (was the chart default `nginx`).
- Objects are named after the release (the controller Service was `ingress-nginx-main-controller`).

## Tests

```sh
scripts/vendor-charts.sh packages/system/ingress-nginx   # download vendor/ (not committed)
helm dependency build packages/system/ingress-nginx
for f in packages/system/ingress-nginx/ci/*-values.yaml; do
  helm lint packages/system/ingress-nginx -f "$f"
  helm template ingress-nginx-ingress-nginx packages/system/ingress-nginx -n ingress-nginx -f "$f" >/dev/null
done
```
