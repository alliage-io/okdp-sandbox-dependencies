# vault

OKDP chart of [HashiCorp Vault](https://www.vaultproject.io/), the secret backend a
project SecretStore (External Secrets Operator) points at. Runs in dev mode by default:
it unseals itself, keeps everything in memory, and the root token is `root`.

It renders the upstream chart `vault` 0.34.1 (https://helm.releases.hashicorp.com; Vault
2.0.4, vault-k8s injector 1.7.6), vendored under `vendor/` (see `vendor.yaml`), with values
computed in `templates/_values.tpl`.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `dev` | `true` | Dev mode (sandbox only). Off, Vault starts sealed with file storage. |
| `ingressHost` | `vault` | Host name; the ingress suffix is appended. |
| `uiEnabled` | `true` | Web UI. |
| `protected` | `true` | Label the StatefulSet and the injector Deployment `okdp.io/protected=true` (deletion refused by the tools chart). |

Platform values read: `global.okdp.ingress.suffix`, `ingress.className`,
`certificateIssuers.selfSigned.name` (all required).

## Changes from the KuboCD package

- The TLS Secret is `<release>-tls` (was `vault-tls`); objects are named after the release.
- `protected: true` (KuboCD) is now the `okdp.io/protected` label.
- Chart 0.34.1 (was 0.29.1): Vault 2.0.4 instead of 1.18.1 (dev mode unchanged).

## Tests

```sh
helm dependency build packages/system/vault
for f in packages/system/vault/ci/*-values.yaml; do
  helm lint packages/system/vault -f "$f"
  helm template vault-vault packages/system/vault -n vault -f "$f" >/dev/null
done
scripts/vendor-charts.sh --check packages/system/vault
```
