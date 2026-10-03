# vault

OKDP chart of [HashiCorp Vault](https://www.vaultproject.io/), the secret backend a
project SecretStore (External Secrets Operator) points at. By default it runs standalone
(file storage) and starts sealed: initialise and unseal it (`vault operator init`,
`vault operator unseal`). `dev: true` (the sandbox sets it explicitly) unseals itself,
keeps everything in memory and has the well-known root token `root`: never use it where
the ingress is reachable by anyone else.

It renders the upstream chart `vault` 0.34.1 (https://helm.releases.hashicorp.com; Vault
2.0.4, vault-k8s injector 1.7.6), vendored under `vendor/` (see `vendor.yaml`), with values
computed in `templates/_values.tpl`.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `dev` | `false` | Dev mode (sandbox only: root token `root`, in-memory store). Off, Vault starts sealed with file storage. |
| `ingressHost` | `vault` | Host name; the ingress suffix is appended. |
| `uiEnabled` | `true` | Web UI. |
| `protected` | `true` | Label the StatefulSet and the injector Deployment `okdp.io/protected=true` (deletion refused by the tools chart). |

Platform values read: `global.okdp.ingress.suffix`, `ingress.className`,
`certificateIssuers.selfSigned.name` (all required).

## Upstream values

Any value of the vendored `vault` chart can be set per instance under
`upstream.vault`, merged over the values computed from the parameters
(okdp-lib-chart `okdp.vendor.render`, option `upstream`):

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
`tls`); see `vault.upstream` in `templates/_values.tpl` (also listed in the
schema description). An upstream value wins over the parameter it overlaps
(`ui.enabled` over `uiEnabled`). No key or value may contain `{{` (the schema
and okdp-lib-chart both refuse it).

## Changes from the KuboCD package

- The TLS Secret is `<release>-tls` (was `vault-tls`); objects are named after the release.
- `protected: true` (KuboCD) is now the `okdp.io/protected` label.
- Chart 0.34.1 (was 0.29.1): Vault 2.0.4 instead of 1.18.1 (dev mode unchanged).
- `dev` defaults to `false` (it was `true`): a chart installed with its defaults no
  longer exposes a Vault with the root token `root` on its ingress. Sandboxes set
  `dev: true` explicitly.

## Tests

```sh
scripts/vendor-charts.sh packages/system/vault   # download vendor/ (not committed)
helm dependency build packages/system/vault
for f in packages/system/vault/ci/*-values.yaml; do
  helm lint packages/system/vault -f "$f"
  helm template vault-vault packages/system/vault -n vault -f "$f" >/dev/null
done
```
