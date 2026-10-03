# dns-server

OKDP chart of a lightweight DNS server ([CoreDNS](https://coredns.io/)) for local
development: every name under the platform ingress suffix
(`global.okdp.ingress.suffix`, e.g. `*.okdp.sandbox`) resolves to `target`, other names
are forwarded to `forwarders` (8.8.8.8 and 8.8.4.4 by default). It is exposed on a
NodePort so the host resolver can use it.

It renders the official CoreDNS chart `coredns` 1.47.1 (https://coredns.github.io/helm,
CoreDNS 1.14.6, image `coredns/coredns`), vendored under `vendor/` (see `vendor.yaml`),
with fixed values in `vendor-values/coredns.yaml` and computed ones in
`templates/_values.tpl`: two server blocks on port 53, the
ingress suffix answered by the `template` plugin (the suffix and every name under it get
`target`, an `A` record, or `AAAA` when `target` is an IPv6 address; other record types
an empty answer) and the root zone sent to `forward`, with `cache`. Queries are logged
(`log`). It is not a cluster DNS: no `kubernetes` plugin, no RBAC.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `target` | `127.0.0.1` | Address returned for every name under the ingress suffix. |
| `nodePort` | `30053` | Node port of the DNS service, UDP and TCP. |
| `forwarders` | `[8.8.8.8, 8.8.4.4]` | Upstream DNS servers for every other name. |

Platform values read: `global.okdp.ingress.suffix` (required).

## Upstream values

Any value of the vendored `coredns` chart can be set per instance under
`upstream.coredns`, merged over the values computed from the parameters
(okdp-lib-chart `okdp.vendor.render`, option `upstream`):

```yaml
upstream:
  coredns:
    image: {repository: mirror.example.org/coredns/coredns}
    tolerations: [{key: dedicated, operator: Exists, effect: NoSchedule}]
    servers:                     # appended to the two computed server blocks
      - zones: [{zone: corp.example., use_tcp: true}]
        port: 53
        plugins: [{name: forward, parameters: . 10.0.0.53}]
```

The paths the platform relies on are refused (names, the Deployment selector,
the NodePort Service, the ConfigMap of the computed server blocks,
`isClusterService`, `rbac.create`, `hpa.enabled`), and `servers` is appended to
rather than replaced: see `dns-server.upstream.options` in
`templates/_values.tpl` (also listed in the schema description). An upstream
value wins over the parameter it overlaps (`resources`). No key or value may
contain `{{` (the schema and okdp-lib-chart both refuse it).

## Changes from the KuboCD package

- CoreDNS (official chart and image) replaces dnsmasq (the personal image
  `4km3/dnsmasq` of the former `oci://quay.io/okdp/charts/dns-server` 1.0.0); the answers
  are the same (`address=/<suffix>/<target>`, the upstream servers).
- TCP uses the same node port as UDP (was `nodePort + 1`).
- `forwarders` is new (the upstream servers were fixed).
- Objects are named after the release (`<project>-<instance>`, e.g. `dns-server-dns-server`);
  the Deployment keeps the selector `app.kubernetes.io/name: dns-server`.

## Tests

```sh
scripts/vendor-charts.sh packages/system/dns-server   # download vendor/ (not committed)
helm dependency build packages/system/dns-server
for f in packages/system/dns-server/ci/*-values.yaml; do
  helm lint packages/system/dns-server -f "$f"
  helm template dns-server-dns-server packages/system/dns-server -n dns-server -f "$f" >/dev/null
done
```
