# vault

OKDP package of [HashiCorp Vault](https://www.vaultproject.io/), the secret backend a
project SecretStore (External Secrets Operator) points at. By default it runs standalone
(file storage) and starts sealed: initialise and unseal it (`vault operator init`,
`vault operator unseal`). `dev: true` (the sandbox sets it explicitly) unseals itself,
keeps everything in memory and has the well-known root token `root`: never use it where
the ingress is reachable by anyone else.

A package in the okdp-compiler format: `Chart.yaml` names the upstream chart `vault`
0.34.1 (https://helm.releases.hashicorp.com; Vault 2.0.4, vault-k8s injector 1.7.6),
rendered from its repository; `values.cel.yaml` computes its values from the parameters
below (`config.schema.json`), over OKDP's defaults `vault.defaults.yaml` (`okdp.yaml`).
The former KuboCD module `main` is the chart `vault`; the service has no object of its
own.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `dev` | `false` | Dev mode (sandbox only: root token `root`, in-memory store). Off, Vault starts sealed with file storage. |
| `ingressHost` | `vault` | Host name; the ingress suffix is appended. |
| `uiEnabled` | `true` | Web UI. |
| `protected` | `true` | Label the pods of the StatefulSet and of the injector Deployment `okdp.io/protected=true` (`server.extraLabels`, `injector.extraLabels`): the tools chart refuses to delete a controller whose pod template carries it. See Known gaps. |

Platform values read: `global.okdp.ingress.suffix`, `ingress.className`,
`certificateIssuers.selfSigned.name` (all required).

## Upstream values

Any value of the `vault` chart can be set per instance under `upstream.vault`,
merged over the values computed from the parameters (`upstream` in `okdp.yaml`):

```yaml
upstream:
  vault:
    server:
      resources: {limits: {memory: 512Mi}}
      dataStorage: {size: 20Gi}
      tolerations: [{key: dedicated, operator: Exists, effect: NoSchedule}]
    injector: {enabled: false}
```

The paths the platform relies on are refused: the names and the Service port
the SecretStores reach (`fullnameOverride`, `nameOverride`,
`server.service.port`), dev mode (`server.dev`: the `dev` parameter only), and
the ingress host and TLS (`server.ingress.enabled`, `ingressClassName`, `hosts`,
`tls`); see `protect` in `okdp.yaml` (also listed in the schema
description). An upstream value wins over the parameter it overlaps
(`ui.enabled` over `uiEnabled`). No key or value may contain `{{` (the schema
and okdp-compile both refuse it).

## Changes from the KuboCD package

- The TLS Secret is `<release>-tls` (was `vault-tls`); objects are named after the release.
- `protected: true` (KuboCD) is now the `okdp.io/protected` label, on the pod templates
  of the StatefulSet and the injector Deployment.
- Chart 0.34.1 (was 0.29.1): Vault 2.0.4 instead of 1.18.1 (dev mode unchanged).
- `dev` defaults to `false` (it was `true`): a chart installed with its defaults no
  longer exposes a Vault with the root token `root` on its ingress. Sandboxes set
  `dev: true` explicitly.

## Known gaps

What the okdp-lib-chart chart did to the rendered objects and the okdp-compiler format
cannot express:

- the `okdp.io/protected: "true"` label (`protected`) is no longer on the StatefulSet
  `<release>` and the Deployment `<release>-agent-injector` themselves: the chart
  post-processed them to add it, and the vault chart has no label value for their
  metadata. It is on their pod templates instead (`server.extraLabels`,
  `injector.extraLabels`, so on the pods too), which the tools chart's second
  ValidatingAdmissionPolicy (pod template labels) matches: their deletion is still
  refused. A selector on `okdp.io/protected=true` lists the pods, not the controllers,
  and unprotecting (`protected: false`) changes the pod templates, so the pods are
  rolled. The CSI provider DaemonSet (`csi.enabled`, off) is labelled itself
  (`csi.daemonSet.extraLabels`), as before;
- the values ConfigMap `<release>-vault-values` (`okdp.io/vendor-values`) is gone: the
  compiled values replace it. What the instance publishes (its URL and usage) is
  `okdp.instance.yaml`, next to the compiled umbrella chart, no longer the descriptor
  ConfigMap `<release>-okdp`.

## Tests

`ci/platform.yaml` holds the platform values of every case; `standalone` has its own
suffix, IngressClass and issuer (`ci/standalone-platform.yaml`); `protected-upstream`
must fail.

```sh
scripts/compile-charts.sh catalog/vault/0.34.1-1.0.0   # compile, check and render ci/*-values.yaml
```
