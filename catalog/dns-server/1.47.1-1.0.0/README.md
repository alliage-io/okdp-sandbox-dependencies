# dns-server

OKDP package of a lightweight DNS server ([CoreDNS](https://coredns.io/)) for local
development: every name under the platform ingress suffix
(`global.okdp.ingress.suffix`, e.g. `*.okdp.sandbox`) resolves to `target`, other names
are forwarded to `forwarders` (8.8.8.8 and 8.8.4.4 by default). It is exposed on a
NodePort so the host resolver can use it.

A package in the okdp-compiler format: `Chart.yaml` names the official CoreDNS
chart `coredns` 1.47.1 (https://coredns.github.io/helm, CoreDNS 1.14.6, image
`coredns/coredns`), rendered from its repository; `values.cel.yaml` computes its
values from the parameters (`config.schema.json`), over OKDP's defaults
`coredns.defaults.yaml` (`okdp.yaml`): two server blocks on port 53, the
ingress suffix answered by the `template` plugin (the suffix and every name under it get
`target`, an `A` record, or `AAAA` when `target` is an IPv6 address; other record types
an empty answer) and the root zone sent to `forward`, with `cache`. Queries are logged
(`log`). It is not a cluster DNS: no `kubernetes` plugin, no RBAC.

| Former module | Now | Compiled when |
|---|---|---|
| `main` | chart `coredns` (coredns/helm 1.47.1) | always |

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `target` | `127.0.0.1` | Address returned for every name under the ingress suffix. |
| `nodePort` | `30053` | Node port of the DNS service, UDP and TCP. |
| `forwarders` | `[8.8.8.8, 8.8.4.4]` | Upstream DNS servers for every other name. |

Platform values read: `global.okdp.ingress.suffix` (required).

## Upstream values

Any value of the `coredns` chart can be set per instance under `upstream.coredns`,
merged over the values computed from the parameters (`upstream` in `okdp.yaml`):

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
rather than replaced: see `protect` and `append` in `okdp.yaml` (also
listed in the schema description). An upstream value wins over the parameter
it overlaps (`resources`). No key or value may contain `{{` (the schema and
okdp-compile both refuse it).

## Changes from the KuboCD package

- CoreDNS (official chart and image) replaces dnsmasq (the personal image
  `4km3/dnsmasq` of the former `oci://quay.io/okdp/charts/dns-server` 1.0.0); the answers
  are the same (`address=/<suffix>/<target>`, the upstream servers).
- TCP uses the same node port as UDP (was `nodePort + 1`).
- `forwarders` is new (the upstream servers were fixed).
- Objects are named after the release (`<project>-<instance>`, e.g. `dns-server-dns-server`);
  the Deployment keeps the selector `app.kubernetes.io/name: dns-server`.

## Known gaps

What okdp-lib-chart did to the rendered objects and values that the
okdp-compiler format cannot express:

- the values ConfigMap `<release>-coredns-values` (`okdp.io/vendor-values`) is
  gone: the compiled values replace it.

Nothing else: the CoreDNS objects already carry `app.kubernetes.io/instance`.
What the instance publishes (its usage) is `okdp.instance.yaml`, next to the
compiled umbrella chart, no longer the descriptor ConfigMap `<release>-okdp`.

## Tests

`ci/platform.yaml` holds the platform values of every case; `custom` has its
own ingress suffix (`ci/custom-platform.yaml`); `no-forwarders` must fail.

```sh
scripts/compile-charts.sh catalog/dns-server/1.47.1-1.0.0   # compile, check and render ci/*-values.yaml
```
